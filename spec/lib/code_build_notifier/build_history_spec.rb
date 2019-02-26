describe CodeBuildNotifier::BuildHistory do
  let(:commit_hash) { 'b2ec4811171dc0755fff2a13f1d547e77c5bb0d6' }
  let(:dynamo_client) { instance_double(Aws::DynamoDB::Client) }
  let(:dynamo_table) { 'test-table-name' }
  let(:project_code) { 'codebuild-ruby2.5' }
  let(:region) { 'us-east-99' }
  let(:source_id) { "#{project_code}:#{trigger}" }
  let(:status) { 'FAILED' }
  let(:trigger) { 'branch/my_branch' }
  let(:branch_name) { 'my_branch' }

  let(:build) do
    instance_double(
      CodeBuildNotifier::CurrentBuild,
      branch_name: branch_name,
      commit_hash: commit_hash,
      launched_by_retry?: false,
      project_code: project_code,
      source_id: source_id,
      status: status,
      trigger: trigger
    )
  end

  let(:config) do
    instance_double(
      CodeBuildNotifier::Config,
      dynamo_table: dynamo_table,
      region: region
    )
  end

  before do
    allow(Aws::DynamoDB::Client).to receive(:new).and_return(dynamo_client)
  end

  describe '#write_entry' do
    let(:history) { described_class.new(config, build) }

    before do
      allow(dynamo_client).to receive(:update_item)
    end

    it 'calls update_item on the dynamo table specified in config' do
      history.write_entry(source_id)

      expect(dynamo_client).to have_received(:update_item)
        .with(hash_including(table_name: dynamo_table))
    end

    it 'yields a hash of the attributes to be updated if a block is specified' do
      expect do |my_block|
        history.write_entry(source_id, &my_block)
      end.to yield_with_args(Hash)
    end

    it 'sets the primary key to the specified source_id' do
      history.write_entry(source_id) do |updates|
        expect(updates[:key]).to eq(source_id: source_id)
      end
    end

    it 'sets an update expression by joining the keys to be updated' do
      history.write_entry(source_id) do |updates|
        expect(updates[:update_expression]).to eq(
          'SET #commit_hash = :commit_hash, ' \
          '#project_code = :project_code, ' \
          '#status = :status, #source_ref = :source_ref, ' \
          '#branch_name = :branch_name'
        )
      end
    end

    it 'it does not set branch name if it is blank' do
      allow(build).to receive(:branch_name).and_return('')
      history.write_entry(source_id) do |updates|
        expect(updates[:update_expression]).to eq(
          'SET #commit_hash = :commit_hash, ' \
          '#project_code = :project_code, ' \
          '#status = :status, #source_ref = :source_ref'
        )
      end
    end

    it 'sets expression attribute names for all the keys to be updated' do
      history.write_entry(source_id) do |updates|
        expect(updates[:expression_attribute_names]).to eq(
          {
            '#branch_name' => 'branch_name',
            '#commit_hash' => 'commit_hash',
            '#project_code' => 'project_code',
            '#source_ref' => 'source_ref',
            '#status' => 'status'
          }
        )
      end
    end

    context 'when the build was launched by Retry command,' do
      before do
        allow(build).to receive(:launched_by_retry?).and_return(true)
      end

      it 'sets the commit hash, project code, and status' do
        history.write_entry(source_id) do |updates|
          expect(updates[:expression_attribute_values]).to include(
            ':commit_hash' => commit_hash,
            ':project_code' => project_code,
            ':status' => status
          )
        end
      end

      it 'does not set a source ref attribute' do
        history.write_entry(source_id) do |updates|
          expect(updates[:expression_attribute_values]).not_to have_key(':source_ref')
        end
      end

      it 'does not set a branch name attribute' do
        history.write_entry(source_id) do |updates|
          expect(updates[:expression_attribute_values]).not_to have_key(':branch_name')
        end
      end
    end

    context 'when the build was not launched by Retry command,' do
      before do
        allow(build).to receive(:launched_by_retry?).and_return(false)
      end

      it 'sets the commit hash, project code, and status' do
        history.write_entry(source_id) do |updates|
          expect(updates[:expression_attribute_values]).to include(
            ':commit_hash' => commit_hash,
            ':project_code' => project_code,
            ':status' => status
          )
        end
      end

      it 'sets the source ref to be the trigger of the build' do
        history.write_entry(source_id) do |updates|
          expect(updates[:expression_attribute_values]).to include(
            ':source_ref' => trigger
          )
        end
      end
    end
  end

  describe '#last_entry' do
    let(:empty_query_results) { Hashie::Mash.new(items: []) }
    let(:empty_get_item_results) { Hashie::Mash.new(item: nil) }

    before do
      allow(dynamo_client).to receive(:query).and_return(empty_query_results)
      allow(dynamo_client).to receive(:get_item).and_return(empty_get_item_results)
    end

    it 'instantiates a dynamo client with the region specified in config' do
      described_class.new(config, build).last_entry

      expect(Aws::DynamoDB::Client).to have_received(:new)
        .with(hash_including(region: region))
    end

    context 'when the build was launched by Retry command' do
      before do
        allow(build).to receive(:launched_by_retry?).and_return(true)
      end

      it 'queries the dynamo table specified in config' do
        described_class.new(config, build).last_entry

        expect(dynamo_client).to have_received(:query)
          .with(hash_including(table_name: dynamo_table))
      end

      it 'queries using the commit hash and project code from the build' do
        described_class.new(config, build).last_entry

        expected_attr_values = {
          ':commit_hash' => commit_hash, ':project_code' => project_code
        }

        expect(dynamo_client).to have_received(:query).with(
          hash_including(expression_attribute_values: expected_attr_values)
        )
      end

      it 'returns nil when no results are found' do
        expect(described_class.new(config, build).last_entry).to be_nil
      end

      context 'when results are found,' do
        let(:value) { 'some_value' }

        let(:query_results) do
          Hashie::Mash.new(items: [{ attr: value }, { other: 'stuff' }])
        end

        before do
          allow(dynamo_client).to receive(:query).and_return(query_results)
        end

        it 'returns a Hashie::Mash initialized with the first result' do
          result = described_class.new(config, build).last_entry
          expect(result.attr).to eq(value)
        end
      end
    end

    context 'when the build was not launched by Retry command' do
      before do
        allow(build).to receive(:launched_by_retry?).and_return(false)
      end

      it 'calls get_item on the dynamo table specified in config' do
        described_class.new(config, build).last_entry

        expect(dynamo_client).to have_received(:get_item)
          .with(hash_including(table_name: dynamo_table))
      end

      it 'specifies the source id of the build as the get_item key' do
        described_class.new(config, build).last_entry

        expect(dynamo_client).to have_received(:get_item)
          .with(hash_including(key: { 'source_id' => source_id }))
      end

      it 'returns nil when no result is found' do
        expect(described_class.new(config, build).last_entry).to be_nil
      end

      context 'when a result is found,' do
        let(:value) { 'some_value' }

        let(:query_results) do
          Hashie::Mash.new(item: { attr: value })
        end

        before do
          allow(dynamo_client).to receive(:get_item).and_return(query_results)
        end

        it 'returns a Hashie::Mash initialized with the first result' do
          result = described_class.new(config, build).last_entry
          expect(result.attr).to eq(value)
        end
      end
    end
  end
end
