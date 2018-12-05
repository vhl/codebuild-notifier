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

      message.recipients.each do |email|
        slack_user_id = find_slack_user(email)
        slack_user_id && post_message(message, slack_user_id)
      end
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
      lookup_response = slack_client.users_lookupByEmail(email: email)
      lookup_response.user.id
    rescue Slack::Web::Api::Errors::SlackError => e
      admin_send(
        "Slack user lookup by email for #{email} failed with " \
        "error: #{e.message}"
      )
      nil
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
