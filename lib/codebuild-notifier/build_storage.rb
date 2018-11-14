module CodeBuildNotifier
  class BuildStorage
    include Environment

    def dynamo_client
      @dynamo_client ||= Aws::DynamoDB::Client.new(region: region)
    end

    def last_build_by_hash
      item = dynamo_client.query(
        expression_attribute_values: {
          ':commit_hash' => commit_hash, ':project_code' => project_code
        },
        filter_expression: 'project_code = :project_code',
        index_name: 'commit_hash_index',
        key_condition_expression: 'commit_hash = :commit_hash',
        table_name: dynamo_table_name
      ).items.first
      @last_build = item && Build.new(item)
    end

    def last_build_by_trigger
      existing_item = dynamo_client.get_item(
        key: { 'source_id' => source_id },
        table_name: dynamo_table_name
      ).item
      @last_build = existing_item && Build.new(existing_item)
    end

    # source_id, the primary key, is a composite of project_code and
    # trigger.
    # e.g.:
    #   my-app_ruby2-4:branch/master
    #   my-app_ruby2-3:pr/4056
    # project_code forms part of the key to support having repos with
    # multiple projects, for example, with different buildspec files for
    # different ruby versions, or for rspec vs cucumber.
    # If we have located a build, use the source_id from that.
    def source_id
      @last_build&.source_id || "#{project_code}:#{trigger}"
    end

    # If we have located a build, use the source_ref from that.
    def source_ref
      @last_build&.source_ref || trigger
    end

    def write_build
      cb_puts "Updating dynamo table #{dynamo_table_name} with: #{new_item.inspect}"
      dynamo_client.put_item(
        item: new_item,
        table_name: dynamo_table_name
      )
    end

    private def new_item
      @new_item ||= {
        commit_hash: commit_hash,
        project_code: project_code,
        source_id: build_store.source_id,
        status: current_status
      }.tap do |memo|
        # If launched via manual re-try instead of via a webhook, we don't want
        # to overwrite the current source_ref value that tells us which branch or
        # pull request originally created the dynamo record.
        memo[:source_ref] = trigger if trigger != ''
      end
    end

    class Build
      def initialize(dynamo_record)
        @dynamo_record = dynamo_record
      end

      def source_id
        @dynamo_record['source_id']
      end

      def source_ref
        @dyanmo_record['source_ref']
      end

      def status
        @dyanmo_record['status']
      end
    end
  end
end
