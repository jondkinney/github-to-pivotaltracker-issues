#!/usr/bin/env ruby

# Description:  Migrates GitHub Issues to Pivotal Tracker.

GITHUB_USER = ''
GITHUB_REPO = ''
GITHUB_LOGIN = ''
PIVOTAL_PROJECT_ID =
PIVOTAL_PROJECT_USE_SSL = false

GITHUB_PASSWORD = ''
PIVOTAL_TOKEN = ''

require 'rubygems'
require 'octokit'
require 'pivotal-tracker'
require 'json'

# uncomment to debug
#require 'net-http-spy'
#puts ENV['GITHUB_PASSWORD']
#puts ENV['PIVOTAL_TOKEN']

dry_run = false

begin

  PivotalTracker::Client.token = PIVOTAL_TOKEN
  PivotalTracker::Client.use_ssl = PIVOTAL_PROJECT_USE_SSL

  pivotal_project = nil

  pivotal_project = PivotalTracker::Project.find(PIVOTAL_PROJECT_ID)

  github = Octokit::Client.new(:login => GITHUB_LOGIN, :password => GITHUB_PASSWORD)

  issues_filter = 'push' # update filter as appropriate

  story_type = 'feature' # 'bug', 'feature', 'chore', 'release'. Omitting makes it a feature.

  story_current_state = 'unscheduled' # 'unscheduled', 'started', 'accepted', 'delivered', 'finished', 'unscheduled'.
                                      # 'unstarted' puts it in 'Current' if Commit Mode is on; 'Backlog' if Auto Mode is on.
                                      # Omitting puts it in the Icebox.

  total_issues = 0

  page_issues = 1
  issues = github.list_issues(GITHUB_REPO, { :page => page_issues, :labels => issues_filter } )

  while issues.count > 0

    issues.each do |issue|
      total_issues += 1
      comments = github.issue_comments(GITHUB_REPO, issue.number)

      labels = ''
      issue.labels.each do |l|
        labels += ",#{l.name}"
      end

      puts "issue: #{issue.number} #{issue.title}, with #{comments.count} comments"

      unless dry_run
        story = pivotal_project.stories.create(
          name: issue.title,
          description: issue.body,
          labels: 'app redesign',
          story_type: story_type,
          current_state: story_current_state
        )


        story.notes.create(
          text: "Migrated from #{issue.html_url}",
        )

        comments.each do |comment|
          story.notes.create(
            text: comment.body.gsub(/\r\n\r\n/, "\n\n"),
            author: comment.user.login,
            noted_at: comment.created_at
          )
        end

        github.add_comment(GITHUB_REPO, issue.number, "Migrated to pivotal tracker #{story.url}")
        #github.close_issue(GITHUB_REPO, issue.number)
      end
    end

    page_issues += 1
    issues = github.list_issues(GITHUB_REPO, { :page => page_issues, :labels => issues_filter } )
  end

  puts "\n== processed #{total_issues} issues"

rescue StandardError => se
  puts se.message
  exit 1
end
