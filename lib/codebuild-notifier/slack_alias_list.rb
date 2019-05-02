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
  class SlackAliasList < DynamoBase
    attr_reader :table_name

    def initialize(config)
      super(config, nil)
      @table_name = config.slack_alias_table
    end

    def find(email)
      dynamo_client.get_item(
        table_name: table_name,
        key: { 'alternate_email' => email }
      ).item&.fetch('main_email')
    end
  end
end
