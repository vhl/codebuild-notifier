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
  class SlackMessage
    attr_reader :build, :config

    delegate :author_email, :author_name, :committer_email,
             :commit_message_subject, :short_hash, :source_ref, to: :build

    def initialize(build, config)
      @build = build
      @config = config
    end

    def payload
      {
        color: slack_color,
        fallback: [title, body].join("\n"),
        title: title,
        text: body
      }
    end

    def recipients
      [author_email, committer_email].uniq
    end

    def additional_channel
      !build.for_pr? && config.additional_channel
    end

    private def slack_color
      {
        'FAILED' => 'danger',
        'SUCCEEDED' => 'good'
      }[build.status]
    end

    private def title
      "#{slack_icon} #{author_name}'s " \
      "<#{details_url}|#{build.project_code} build> - " \
      "#{build.status.downcase}"
    end

    private def slack_icon
      {
        'FAILED' => ':broken_heart:',
        'SUCCEEDED' => ':green_heart:'
      }[build.status]
    end

    private def details_url
      'https://console.aws.amazon.com/codesuite/codebuild/projects/' \
      "#{build.project_code}/build/#{build.build_id}/log?region=#{config.region}"
    end

    private def body
      "commit #{commit_link} (#{commit_message_subject}) in " \
      "#{source_ref_link}"
    end

    private def commit_link
      "<#{build.git_repo_url}/commit/#{build.commit_hash}|#{short_hash}>"
    end

    private def source_ref_link
      "<#{build.git_repo_url}/#{url_path}|#{source_ref}>"
    end

    private def url_path
      if %r{\Apr/}.match?(source_ref)
        "pull/#{source_ref[3..-1]}"
      else
        "tree/#{source_ref.gsub(%r{\Abranch/}, '')}"
      end
    end
  end
end
