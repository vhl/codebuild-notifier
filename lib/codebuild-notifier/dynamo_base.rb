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

require 'active_support'
require 'active_support/core_ext'
require 'aws-sdk-dynamodb'
require 'hashie'

module CodeBuildNotifier
  class DynamoBase
    attr_reader :config, :current_build

    delegate :dynamo_table, to: :config

    def initialize(config, build)
      @config = config
      @current_build = build
    end

    private def update_item(updates)
      dynamo_client.update_item(
        updates.merge(table_name: dynamo_table)
      )
    end

    private def dynamo_client
      @dynamo_client || Aws::DynamoDB::Client.new(region: config.region)
    end

    private def hash_to_dynamo_update(hash)
      update = hash.each_with_object(
        expression_attribute_names: {},
        expression_attribute_values: {},
        update_expression: []
      ) do |(key, value), memo|
        memo[:expression_attribute_names]["##{key}"] = key.to_s
        memo[:expression_attribute_values][":#{key}"] = value
        memo[:update_expression] << "##{key} = :#{key}"
      end
      update.merge(update_expression: "SET #{update[:update_expression].join(', ')}")
    end
  end
end
