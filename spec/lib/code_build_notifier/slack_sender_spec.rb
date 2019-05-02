describe CodeBuildNotifier::SlackSender do
  let(:author_email) { 'author@workspace.com' }
  let(:author_slack_id) { 'U1040B40' }
  let(:dynamo_client) { instance_double(Aws::DynamoDB::Client) }
  let(:payload) { { text: 'happy_message' } }
  let(:region) { 'us-east-99' }
  let(:app_auth_token) { 'xoxp-my-app-token' }
  let(:bot_auth_token) { 'xoxb-my-bot-user-token' }
  let(:secret_item) { Hashie::Mash.new(secret_string: json_secret) }
  let(:json_secret) { { token: app_auth_token }.to_json }
  let(:slack_secret_name) { 'slack/codebuild-secret' }
  let(:secrets_client) { instance_double(Aws::SecretsManager::Client) }

  let(:slack_client) do
    instance_double(
      Slack::Web::Client,
      chat_postMessage: true,
      users_lookupByEmail: Hashie::Mash.new(user: {})
    )
  end

  let(:config) do
    instance_double(
      CodeBuildNotifier::Config,
      dynamo_client: dynamo_client,
      region: region,
      slack_admins: [],
      slack_alias_table: nil,
      slack_secret_name: slack_secret_name
    )
  end

  let(:slack_message) do
    instance_double(
      CodeBuildNotifier::SlackMessage,
      additional_channel: false,
      payload: payload,
      recipients: [author_email]
    )
  end

  before do
    allow(Aws::SecretsManager::Client).to receive(:new).and_return(secrets_client)
    allow(secrets_client).to receive(:get_secret_value).and_return(secret_item)
    allow(Slack::Web::Client).to receive(:new).and_return(slack_client)
  end

  describe '#send' do
    it 'instantiates a SecretsManager client specifying the region specified ' \
       'in the config' do
      described_class.new(config).send(slack_message)

      expect(Aws::SecretsManager::Client).to have_received(:new)
        .with(region: region)
    end

    it 'looks up the SecretsManager secret using the slack secret name ' \
       'specified in the config' do
      described_class.new(config).send(slack_message)

      expect(secrets_client).to have_received(:get_secret_value)
        .with(secret_id: slack_secret_name)
    end

    it 'configures slack with the token from secrets manager' do
      described_class.new(config).send(slack_message)

      expect(Slack.config.token).to eq(app_auth_token)
    end

    context 'when the slack message specifies an additional channel' do
      it 'posts a chat message to the specified channel' do
        channel = '#target'
        allow(slack_message).to receive(:additional_channel).and_return(channel)

        described_class.new(config).send(slack_message)

        expect(slack_client).to have_received(:chat_postMessage).with(
          hash_including(attachments: [payload], channel: channel)
        )
      end

      it 'prepends # to the channel if it does not start with #' do
        channel = 'target'
        allow(slack_message).to receive(:additional_channel).and_return(channel)

        described_class.new(config).send(slack_message)

        expect(slack_client).to have_received(:chat_postMessage).with(
          hash_including(attachments: [payload], channel: "##{channel}")
        )
      end
    end

    it 'looks up the slack user id for the email address of each recipient' do
      described_class.new(config).send(slack_message)

      expect(slack_client).to have_received(:users_lookupByEmail)
        .with(email: author_email)
    end

    context 'when the slack user id lookup succeeds,' do
      before do
        allow(slack_client).to receive(:users_lookupByEmail).and_return(
          Hashie::Mash.new(user: { id: author_slack_id })
        )
      end

      it 'posts a chat message to the author with the attachment set to the ' \
         'payload of the specified slack message ' do
        described_class.new(config).send(slack_message)

        expect(slack_client).to have_received(:chat_postMessage).with(
          hash_including(attachments: [payload], channel: author_slack_id)
        )
      end

      context 'when the auth token starts with xoxb,' do
        let(:json_secret) { { token: bot_auth_token }.to_json }

        it 'posts a message to the author as a bot user' do
          described_class.new(config).send(slack_message)

          expect(slack_client).to have_received(:chat_postMessage).with(
            hash_including(as_user: true, channel: author_slack_id)
          )
        end
      end

      context 'when the auth token does not start with xoxb,' do
        let(:json_secret) { { token: app_auth_token }.to_json }

        it 'posts a message to the author as an app' do
          described_class.new(config).send(slack_message)

          expect(slack_client).to have_received(:chat_postMessage).with(
            hash_including(as_user: false, channel: author_slack_id)
          )
        end
      end
    end

    context 'when the slack user id lookup fails,' do
      let(:slack_error_class) { Slack::Web::Api::Errors::SlackError }
      let(:slack_error_message) { 'no user found' }

      context 'when a slack_alias_table is not configured,' do
        before do
          allow(slack_client).to receive(:users_lookupByEmail)
            .and_raise(slack_error_class, slack_error_message)
        end

        it 'does not try to send a slack notification to the author' do
          described_class.new(config).send(slack_message)

          expect(slack_client).not_to have_received(:chat_postMessage)
        end

        it 'does not try to send the error to admins if no slack admin ' \
           'usernames are specified in config' do
          described_class.new(config).send(slack_message)

          expect(slack_client).not_to have_received(:chat_postMessage)
            .with(hash_including(text: /#{slack_error_message}/))
        end

        context 'when slack admin usernames are specified in config,' do
          before do
            allow(config).to receive(:slack_admins).and_return(%w[fred @daphne])
          end

          it 'sends a message to each admin with the error message' do
            described_class.new(config).send(slack_message)

            expect(slack_client).to have_received(:chat_postMessage).with(
              hash_including(channel: '@daphne', text: /#{slack_error_message}/)
            )
          end

          it 'adds @ to any admin usernames that do not already start with @' do
            described_class.new(config).send(slack_message)

            expect(slack_client).to have_received(:chat_postMessage).with(
              hash_including(channel: '@fred', text: /#{slack_error_message}/)
            )
          end
        end
      end

      context 'when a slack_alias_table is configured,' do
        let(:slack_alias_table) { 'slack-aliases' }
        let(:workspace_email) { 'workspace@example.com' }
        let(:empty_item) { Hashie::Mash.new(item: nil) }
        let(:alias_item) do
          Hashie::Mash.new(item: { 'workspace_email' => workspace_email })
        end

        before do
          allow(config).to receive(:slack_alias_table)
            .and_return(slack_alias_table)
          allow(slack_client).to receive(:users_lookupByEmail)
            .with(email: author_email)
            .and_raise(slack_error_class, slack_error_message)
          allow(dynamo_client).to receive(:get_item).and_return(empty_item)
        end

        it 'looks for a slack alias dynamo table entry with the email ' \
           'address of the author' do
          described_class.new(config).send(slack_message)

          expect(dynamo_client).to have_received(:get_item).with(
            hash_including(
              key: { 'alternate_email' => author_email },
              table_name: slack_alias_table
            )
          )
        end

        context 'when the alias lookup returns an email address,' do
          before do
            allow(dynamo_client).to receive(:get_item)
              .with(hash_including(key: { 'alternate_email' => author_email }))
              .and_return(alias_item)
          end

          it 'posts a chat message to the author when a slack user ' \
             'exists with the alias email address' do
            allow(slack_client).to receive(:users_lookupByEmail)
              .with(email: workspace_email).and_return(
                Hashie::Mash.new(user: { id: author_slack_id })
              )

            described_class.new(config).send(slack_message)

            expect(slack_client).to have_received(:chat_postMessage).with(
              hash_including(channel: author_slack_id)
            )
          end

          it 'does not try to send a slack notification when no slack ' \
             'user exists with the alias email address' do
            allow(slack_client).to receive(:users_lookupByEmail)
              .with(email: workspace_email)
              .and_raise(slack_error_class, slack_error_message)

            described_class.new(config).send(slack_message)

            expect(slack_client).not_to have_received(:chat_postMessage)
          end
        end

        it 'does not try to send a slack notification to the author' \
           'when the alias lookup returns no results' do
          allow(dynamo_client).to receive(:get_item).and_return(empty_item)

          described_class.new(config).send(slack_message)

          expect(slack_client).not_to have_received(:chat_postMessage)
        end
      end
    end
  end
end
