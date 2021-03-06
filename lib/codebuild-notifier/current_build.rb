# codebuild-notifier
# Copyright © 2018 Adam Alboyadjian <adam@cassia.tech>
# Copyright © 2018 Vista Higher Learning, Inc.
#
# codebuild-notifier is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later version.
#
# codebuild-notifier is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with codebuild-notifier.  If not, see <http://www.gnu.org/licenses/>.

module CodeBuildNotifier
  class CurrentBuild
    attr_accessor :previous_build
    attr_reader :build_id, :commit_hash, :git_repo_url, :source_version,
                :start_time, :status_code, :trigger

    # attrs from git info
    attr_reader :author_email, :author_name, :committer_email, :committer_name,
                :commit_message_subject, :short_hash

    # Default values are extracted from CODEBUILD_* ENV vars present in each
    # CodeBuild # job container.
    def initialize(
      build_id: ENV['CODEBUILD_BUILD_ID'],
      commit_hash: ENV['CODEBUILD_RESOLVED_SOURCE_VERSION'],
      git_repo: ENV['CODEBUILD_SOURCE_REPO_URL'],
      head_ref: ENV['CODEBUILD_WEBHOOK_HEAD_REF'],
      start_time: ENV['CODEBUILD_START_TIME'],
      status_code: ENV['CODEBUILD_BUILD_SUCCEEDING'],
      source_version: ENV['CODEBUILD_SOURCE_VERSION'],
      trigger: ENV['CODEBUILD_WEBHOOK_TRIGGER']
    )
      @build_id = build_id
      @commit_hash = commit_hash
      # Handle repos specified with and without optional .git suffix.
      @git_repo_url = git_repo.to_s.gsub(/\.git\z/, '')
      @head_ref = head_ref
      @source_version = source_version
      @start_time = start_time || (Time.now.to_f * 1_000).to_i
      @status_code = status_code
      @trigger = trigger

      @short_hash, @author_name, @author_email,
        @committer_name, @committer_email,
        @commit_message_subject = git_info
    end

    # If launched via retry, the webhook head ref env var is blank,
    # but if the previous build for this branch has been located,
    # the branch_name of that build is the same as for this build
    def branch_name
      if launched_by_retry?
        previous_build&.branch_name
      else
        @head_ref.to_s.gsub(%r{^refs/heads/}, '')
      end
    end

    def status
      status_code.to_s == '1' ? 'SUCCEEDED' : 'FAILED'
    end

    def project_code
      @project_code ||= build_id.split(':').first
    end

    # If trigger is empty, this build was launched using the Retry command from
    # the console or api.
    def launched_by_retry?
      trigger.to_s.empty?
    end

    def for_pr?
      %r{^pr/}.match?(source_version.to_s)
    end

    # source_id, the primary key, is a composite of project_code and
    # trigger.
    # e.g.:
    #   my-app_ruby2-4:branch/master
    #   my-app_ruby2-3:pr/4056
    # project_code forms part of the key to support having repos with
    # multiple projects, for example, with different buildspec files for
    # different ruby versions, or for rspec vs cucumber.
    def source_id
      # If launched via retry, trigger is blank, but if the previous
      # build for this branch has been located, the source_id of that
      # build is the same as for this build
      if launched_by_retry?
        previous_build&.source_id
      else
        "#{project_code}:#{trigger}"
      end
    end

    def source_ref
      # If launched via retry, trigger is blank, but if the previous
      # build for this branch has been located, the source_ref of that
      # build is the same as for this build
      if launched_by_retry?
        previous_build&.source_ref
      else
        trigger
      end
    end

    def history_fields
      {
        author_email: author_email,
        author_name: author_name,
        build_id: build_id,
        commit_hash: commit_hash,
        commit_subject: commit_message_subject,
        committer_email: committer_email,
        committer_name: committer_name,
        git_repo_url: git_repo_url,
        project_code: project_code,
        start_time: start_time,
        status: status
      }
    end

    private def git_info
      Git.current_commit
    end
  end
end
