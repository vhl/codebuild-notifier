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
  class BranchEntry < DynamoBase
    # Creates entries in a partition key with hardcoded primary key.
    # Within the partition key, there is one record for each github repo.
    # The 'projects' field in that record is a Map data type, keyed off
    # project code, containing the status of the last build for that code.
    def update
      updates = hash_to_dynamo_update(branch_entry).merge(
        key: { source_id: source_id, version_key: version_key }
      )
      yield updates if block_given?
      update_item(updates)
    end

    private def branch_entry
      {
        branch_name: current_build.branch_name,
        build_id: current_build.build_id,
        commit_hash: source_id,
        git_repo_url: current_build.git_repo_url,
        source_ref: current_build.source_ref,
        status: current_build.status,
        timestamp: current_build.start_time.to_i
      }
    end

    private def source_id
      current_build.project_code
    end

    private def version_key
      Digest::MD5.hexdigest(current_build.source_ref)
    end
  end
end
