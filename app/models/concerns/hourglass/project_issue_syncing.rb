module Hourglass::ProjectIssueSyncing
  extend ActiveSupport::Concern

  included do
    before_validation :sync_issue_and_project

    validate :validate_issue_project_is_sync
  end

  def sync_issue_and_project
    self.project = issue.project if issue.present? and (project.nil? or project_id != issue.project_id)
  end

  def validate_issue_project_is_sync
    errors.add :issue_id, :invalid if (issue_id && !issue) || (issue && project != issue.project)
  end
end
