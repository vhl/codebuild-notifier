module CodeBuildNotifier
  class SlackMessage
    attr_reader :author_email, :author_name, :build, :committer_email,
                :commit_message_subject, :config, :short_hash, :source_ref

    def initialize(build, config, source_ref)
      @build = build
      @config = config
      @source_ref = source_ref
      @short_hash, @author_name, @author_email,
        @committer_email, @commit_message_subject = git_info
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

    private def git_info
      Git.current_commit
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
