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

require 'digest'

module CodeBuildNotifier
  class ProjectSummary < DynamoBase
    # Creates entries in a partition key with hardcoded primary key.
    # Within the partition key, there is one record for each github repo.
    # The 'projects' field in that record is a Map data type, keyed off
    # project code, containing the status of the last build for that code.
    def update
      return unless whitelisted_branch?

      updates = project_summary_entry
      yield updates if block_given?
      update_item(updates)
    end

    private def whitelisted_branch?
      config.whitelist_branches.include?(current_build.branch_name)
    end

    private def project_summary_entry
      {
        key: { source_id: source_id, version_key: version_key },
        expression_attribute_names: attr_names,
        expression_attribute_values: attr_values,
        update_expression: update_expression
      }
    end

    private def new_record?
      return @new_record if defined?(@new_record)

      item = dynamo_client.get_item(
        key: {
          'source_id' => source_id, 'version_key' => version_key
        },
        table_name: dynamo_table
      ).item
      @new_record = item.nil?
    end

    private def source_id
      'project_summary'
    end

    # The repo url isn't a good format to use as a URL param.
    private def version_key
      Digest::MD5.hexdigest(current_build.git_repo_url)
    end

    private def attr_names
      {
        '#commit_hash' => 'commit_hash',
        '#git_repo_url' => 'git_repo_url',
        '#timestamp' => 'timestamp',
        '#projects' => 'projects'
      }.merge(project_code_attr_name)
    end

    # For an existing record, the project key already exists, so
    # an attribute name is needed to be able to update the nested item
    # path. For a new record, the project code is specified as the root
    # key of the value assigned to the projects field.
    private def project_code_attr_name
      if new_record?
        {}
      else
        { '#project_code' => current_build.project_code }
      end
    end

    private def attr_values
      {
        ':build_status' => status_value,
        ':commit_hash' => source_id,
        ':git_repo_url' => current_build.git_repo_url,
        ':timestamp' => current_build.start_time.to_i
      }
    end

    private def status_map
      {
        'build_id' => current_build.build_id,
        'status' => current_build.status,
        'timestamp' => current_build.start_time.to_i
      }
    end

    # If a record already exists, we can address the nested item path for
    # the current project directly and just store the updated status.
    # Otherwise, we have to create a new map object in the projects field.
    private def status_value
      if new_record?
        { current_build.project_code => status_map }
      else
        status_map
      end
    end

    private def update_expression
      projects_key = new_record? ? '#projects' : '#projects.#project_code'
      'SET #commit_hash = :commit_hash, ' \
      '#timestamp = :timestamp, ' \
      '#git_repo_url = :git_repo_url, ' \
      "#{projects_key} = :build_status"
    end
  end
end
