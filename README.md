# codebuild-notifier
Reports status of AWS CodeBuild CI jobs to slack.

# Infrastructure Requirements

### A DynamoDB table:
 - expected to be named 'branch-build-status', but can be configured
 - the following definition:

```ruby
  AttributeDefinitions [
    { AttributeName: 'source_id', AttributeType: 'S' },
    { AttributeName: 'commit_hash', AttributeType: 'S' }
  ]
  GlobalSecondaryIndexes [
    {
      IndexName: 'commit_hash_index',
      KeySchema: [
        { AttributeName: 'commit_hash', KeyType: 'HASH' }
      ],
      Projection: { ProjectionType: 'ALL' },
    }
  ]
  KeySchema [
    { AttributeName: 'source_id', KeyType: 'HASH' }
  ]
```

### A secret in AWS Secrets Manager:
 - expected to be named 'slack/code-build', but can be configured
 - contents should be:
```json
   { "token": "xoxo-your-slack-app-token" }
```

### IAM Service Role for Code Build projects:

You will likely already have a service role granting cloudwatch access, to 
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
    "arn:aws:dynamodb:<your-region>:<your-account-id>:table/branch-build-status",
    "arn:aws:dynamodb:<your-region>:<your-account-id>:table/branch-build-status/*"
  ]
},
{
  "Action": "secretsmanager:GetSecretValue",
  "Effect": "Allow",
  "Resource": [
    "arn:aws:secretsmanager:<your-region>:<your-account-id>:secret:slack/code-build*"
  ]
}
```        
