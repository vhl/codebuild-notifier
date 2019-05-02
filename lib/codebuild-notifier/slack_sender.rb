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

require 'aws-sdk-secretsmanager'
require 'slack-ruby-client'

module CodeBuildNotifier
  class SlackSender
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def send(message)
      Slack.configure { |slack_config| slack_config.token = app_token }
      channel = message.additional_channel
      if channel
        channel = "##{channel}" unless /\A#/.match?(channel)
        post_message(message, channel)
      end

      user_ids = message.recipients.map { |email| find_slack_user(email)&.id }
      user_ids.uniq.compact.each { |user_id| post_message(message, user_id) }
    end

    private def post_message(message, channel)
      slack_client.chat_postMessage(
        as_user: app_is_bot_user?,
        attachments: [message.payload],
        channel: channel
      )
    end

    private def admin_send(message)
      config.slack_admins.each do |username|
        username = "@#{username}" unless /\A@/.match?(username)
        slack_client.chat_postMessage(
          as_user: false,
          text: message,
          channel: username
        )
      end
    end

    private def find_slack_user(email)
      slack_client.users_lookupByEmail(email: email)&.user
    rescue Slack::Web::Api::Errors::SlackError => e
      alias_email = find_alias(email)
      if alias_email
        find_slack_user(alias_email)
      else
        report_lookup_failure(email, e.message)
        nil
      end
    end

    private def report_lookup_failure(email, error_message)
      admin_send(
        "Slack user lookup by email for #{email} failed with " \
        "error: #{error_message}"
      )
    end

    def find_alias(email)
      config.slack_alias_table && config.dynamo_client.get_item(
        table_name: config.slack_alias_table,
        key: { 'alternate_email' => email }
      ).item&.fetch('workspace_email')
    end

    # If the app token starts with xoxb- then it is a Bot User Oauth token
    # and slack notifications should be posted with as_user: true. If it
    # starts with xoxp- then it's an app token not associated with a user,
    # and as_user: should be false.
    private def app_is_bot_user?
      /\Axoxb/.match?(app_token)
    end

    private def secrets_client
      Aws::SecretsManager::Client.new(region: config.region)
    end

    private def slack_client
      @slack_client ||= Slack::Web::Client.new
    end

    private def app_token
      @app_token ||= JSON.parse(secret.secret_string)['token']
    end

    private def secret
      secrets_client.get_secret_value(secret_id: config.slack_secret_name)
    end
  end
end
