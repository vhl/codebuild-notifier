# codebuild-notifier
Reports status of AWS CodeBuild CI jobs to slack.

# Infrastructure Requirements

### Slack App or Bot in your workspace

Notifications will be sent as slack Direct Messages to users from the default
Slack bot in your workspace (e.g. @slackbot)
- Go to <a href="https://api.slack.com/apps">https://api.slack.com/apps</a>
- Create a New App, e.g. App Name: CodeBuild Notifier
- Under *Add features and functionality* select "Permissions" and grant these scopes:
  - chat:write:bot
  - users:read
  - users:read.email
- Click *Install App To Workspace* and store the OAuth token generated in a new
secret in AWS Secrets Manager (<a href="#secret-in-aws-secrets-manager">see below</a>)

*Optional* Add a Bot User to your app - instead of the default Slack bot, messages
will come from a user with a name you choose, e.g. CodeBuildBot
- Under Features / Bot Users, click *Add a Bot User*
- Select a name and display name; the always show as online option does not matter
- After adding the Bot User, re-install the app to your workspace
- A new OAuth token will be generated specific to the Bot User. Store this in
AWS Secrets Manager instead of the App token.

### DynamoDB table
 - expected to be named 'codebuild-history', but can be configured
 - the following definition:

```ruby
  AttributeDefinitions [
    { AttributeName: 'commit_hash', AttributeType: 'S' },
    { AttributeName: 'source_id', AttributeType: 'S' },
    { AttributeName: 'version_key', AttributeType: 'S' }
  ]
  GlobalSecondaryIndexes [
    {
      IndexName: 'commit_hash_index',
      KeySchema: [
        { AttributeName: 'commit_hash', KeyType: 'HASH' },
        { AttributeName: 'version_key', KeyType: 'RANGE' }
      ],
      Projection: { ProjectionType: 'ALL' }
    }
  ]
  KeySchema [
    { AttributeName: 'source_id', KeyType: 'HASH' },
    { AttributeName: 'version_key', KeyType: 'RANGE' }
  ]
```

### Secret in AWS Secrets Manager
 - expected to be named 'slack/codebuild', but can be configured
 - contents should be:
```json
   { "token": "xoxo-your-slack-app-token" }
```

### IAM Service Role for CodeBuild projects

You will likely already have a service role granting CloudWatch access, to
which you will want to add the following, substituing your region,
account id, and if different, dynamo table name and secrets-manager secret
name:
```json
{
  "Action": [
    "dynamodb:BatchGetItem",
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:Query",
    "dynamodb:Scan",
    "dynamodb:UpdateItem"
  ],
  "Effect": "Allow",
  "Resource": [
    "arn:aws:dynamodb:<your-region>:<your-account-id>:table/codebuild-history",
    "arn:aws:dynamodb:<your-region>:<your-account-id>:table/codbuild-history/*"
  ]
},
{
  "Action": "secretsmanager:GetSecretValue",
  "Effect": "Allow",
  "Resource": [
    "arn:aws:secretsmanager:<your-region>:<your-account-id>:secret:slack/codebuild*"
  ]
}
```

# Configuration

## Installation

### Pre-requisites

The base docker image used for your CodeBuild project must include ruby, or
you must install it using the project's buildspec.yml file.
Any ruby from 2.3.x to 2.5.x will work.

### Using buildspec

Add to the `install:` phase of your buildspec.yml

```yml
phases:
  install:
    commands:
      - gem install codebuild-notifier
```

### Using custom Docker image

Add to your Dockerfile
```
RUN gem install codebuild-notifier
```

## Usage

Add to the `post_build:` phase of your buildspec.yml file

```yml
phases:
  post_build:
    commands:
      - update-build-status
```

## Configuration

### ENV vars

ENV vars can either be set in Dockerfile e.g.
```
ENV CBN_SLACK_ADMIN_USERNAMES scooby,shaggy
```

Or in buildspec.yml
```
env:
  variables:
    CBN_SLACK_ADMIN_USERNAMES: 'fred,velma'
```

### command-line

In buildspec.yml

```yml
phases:
  post_build:
    commands:
      - update-build-status --slack-admin-usernames="fred,velma"
```

### Options

<table>
  <tr>
    <th>ENV var</th>
    <th>command-line</th>
    <th>Default value</th>
    <th>Notes</th>
  </tr>
  <tr>
    <th>
      CBN_ADDITIONAL_CHANNEL
    </th>
    <td>
      <nobr>--additional-channel</nobr>
    </td>
    <td>
      not set
    </td>
    <td>
      If whitelist branches are set, status notifications for these
      branches can be sent to this channel, as well as direct messages
      to the author/committer of the commit triggering the build.
    </td>
  </tr>
  <tr>
    <th>
      CBN_AWS_REGION
    </th>
    <td>
      <nobr>--region</nobr>
    </td>
    <td>
      value of AWS_REGION env var in CodeBuild container
    </td>
    <td>
      If for some reason the dynamo table and secrets-manager live in a
      different region than where CodeBuild is executing, you can specify
      that region.
    </td>
  </tr>
  <tr>
    <th>
      CBN_DEFAULT_NOTIFY_STRATEGY
    </th>
    <td>
      <nobr>--default-notify-strategy</nobr>
    </td>
    <td>
      fail_or_status_change
    </td>
    <td>
      Determines when notifications will be sent.
      'status_change' sends notifications for the first build in a PR or
      whitelisted branch, thereafter if a build in that PR/branch has a
      different status to the previous build.
      'every_build' sends a notification regardless of status.
      'fail_or_status_change', the default value, will send if the status
      changes, but will also send notifications of every failure,
      regardless of previous status.
    </td>
  </tr>
  <tr>
    <th>
      CBN_DYNAMO_TABLE
    </th>
    <td>
      <nobr>--dynamo-table</nobr>
    </td>
    <td>
      codebuild-history
    </td>
    <td>
      This table must be created and permissions granted to it as described
      in <a href="#infrastructure-requirements">Infrastructure Requirements</a>
    </td>
  </tr>
  <tr>
    <th>
      CBN_OVERRIDE_NOTIFY_STRATEGY
    </th>
    <td>
      <nobr>--override-notify-strategy</nobr>
    </td>
    <td>
      not set
    </td>
    <td>
      Allows overriding default notify strategy.
      Specify a branch and strategy for that branch, with a colon separator.
      Valid strategies are:
      status_change, every_build, fail_or_status_change
      Specify multiple branch strategies delimited by comma.
      e.g. 'master:every_build,jira-15650:status_change'
    </td>
  </tr>
  <tr>
    <th>
      CBN_SLACK_ADMIN_USERNAMES
    </th>
    <td>
      <nobr>--slack-admin-usernames</nobr>
    </td>
    <td>
      not set
    </td>
    <td>
      If no slack user can be found in your workspace with the email
      address of the author or committer of a commit, a message will be
      sent to the slack usernames specified.<br />
      Separate multiple values with commas, with no spaces.<br />
      e.g. fred,velma
    </td>
  </tr>
  <tr>
    <th>
      CBN_SLACK_SECRET_NAME
    </th>
    <td>
      <nobr>--slack-secret-name</nobr>
    </td>
    <td>
      slack/codebuild
    </td>
    <td>
      The name of a secret in AWS Secrets Manager with the app or bot auth token.
    </td>
  </tr>
  <tr>
    <th>
      CBN_WHITELIST_BRANCHES
    </th>
    <td>
      <nobr>--whitelist-branches</nobr>
    </td>
    <td>
      master
    </td>
    <td>
      Normally statuses will be stored and notifications sent only for builds
      triggered by commits to branches with open Pull Requests. However, it
      can be useful to get notifications for all commits to certain branches,
      regardless of Pull Request status.<br />
      Separate multiple values with commas, without spaces.<br />
      e.g. 'master,nightly,jira-50012'
    </td>
  </tr>
</table>
