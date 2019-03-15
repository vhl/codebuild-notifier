describe CodeBuildNotifier::BuildHistory do
  let(:branch_name) { 'my_branch' }
  let(:commit_hash) { 'b2ec4811171dc0755fff2a13f1d547e77c5bb0d6' }
  let(:dynamo_client) { instance_double(Aws::DynamoDB::Client) }
  let(:dynamo_table) { 'test-table-name' }
  let(:project_code) { 'codebuild-ruby2.5' }
  let(:region) { 'us-east-99' }
  let(:source_id) { "#{project_code}:#{trigger}" }
  let(:source_version) { commit_hash }
  let(:status) { 'FAILED' }
  let(:trigger) { 'branch/my_branch' }

  let(:author_email) { 'velma@dinkley.org' }
  let(:author_name) { 'Velma Dinkley' }
  let(:commit_subject) { 'Patch holes in van' }
  let(:committer_email) { 'daphne@blake.org' }
  let(:committer_name) { 'Daphne Blake' }
  let(:short_hash) { 'e397ece' }
  let(:start_time) { '244059876000' }

  let(:build) do
    instance_double(
      CodeBuildNotifier::CurrentBuild,
      branch_name: branch_name,
      commit_hash: commit_hash,
      for_pr?: true,
      launched_by_retry?: false,
      project_code: project_code,
      source_id: source_id,
      source_version: source_version,
      start_time: start_time,
      trigger: trigger,
      history_fields: {
        author_email: author_email
      }
    )
  end

  let(:config) do
    instance_double(
      CodeBuildNotifier::Config,
      dynamo_table: dynamo_table,
      region: region
    )
  end

  let(:project_summary) do
    instance_double(CodeBuildNotifier::ProjectSummary, update: true)
  end

  let(:branch_entry) do
    instance_double(CodeBuildNotifier::BranchEntry, update: true)
  end

  before do
    allow(Aws::DynamoDB::Client).to receive(:new).and_return(dynamo_client)
  end

  describe '#write_entry' do
    let(:history) { described_class.new(config, build) }

    before do
      allow(dynamo_client).to receive(:update_item)
      allow(CodeBuildNotifier::ProjectSummary).to receive(:new)
        .and_return(project_summary)
      allow(CodeBuildNotifier::BranchEntry).to receive(:new)
        .and_return(branch_entry)
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

    it 'sets the primary partition key to the specified source_id' do
      history.write_entry(source_id) do |updates|
        expect(updates[:key]).to include(source_id: source_id)
      end
    end

    it 'sets an update expression by joining the keys to be updated' do
      history.write_entry(source_id) do |updates|
        expect(updates[:update_expression]).to eq(
          'SET #author_email = :author_email, ' \
          '#source_ref = :source_ref, #branch_name = :branch_name'
        )
      end
    end

    it 'does not set branch name if it is blank' do
      allow(build).to receive(:branch_name).and_return('')
      history.write_entry(source_id) do |updates|
        expect(updates[:update_expression]).to eq(
          'SET #author_email = :author_email, ' \
          '#source_ref = :source_ref'
        )
      end
    end

    it 'sets expression attribute names for all the keys to be updated' do
      history.write_entry(source_id) do |updates|
        expect(updates[:expression_attribute_names]).to eq(
          '#author_email' => 'author_email',
          '#branch_name' => 'branch_name',
          '#source_ref' => 'source_ref'
        )
      end
    end

    it 'insantiates a new ProjectSummary instance, passing in config and ' \
       'current build' do
      history.write_entry(source_id)

      expect(CodeBuildNotifier::ProjectSummary).to have_received(:new).with(
        config, build
      )
    end

    it 'updates the project summary' do
      history.write_entry(source_id)

      expect(project_summary).to have_received(:update)
    end

    it 'insantiates a new BranchEntry instance, passing in config and ' \
       'current build' do
      history.write_entry(source_id)

      expect(CodeBuildNotifier::BranchEntry).to have_received(:new).with(
        config, build
      )
    end

    it 'updates the branch entry' do
      history.write_entry(source_id)

      expect(branch_entry).to have_received(:update)
    end

    context 'when the build was launched by Retry command,' do
      let(:old_start_time) { '1552501476000' }

      before do
        allow(dynamo_client).to receive(:query).and_return(
          Hashie::Mash.new(items: [{ start_time: old_start_time }])
        )
        allow(build).to receive(:launched_by_retry?).and_return(true)
      end

      it 'sets the history fields from the current build' do
        history.write_entry(source_id) do |updates|
          expect(updates[:expression_attribute_values]).to include(
            ':author_email' => author_email
          )
        end
      end

      it 'sets a version key made up of the start time of the ' \
         'last entry and the current build start time' do
        history.write_entry(source_id) do |updates|
          expect(updates[:key]).to include(
            version_key: "#{old_start_time}_#{start_time}"
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

      it 'sets the history fields from the current build' do
        history.write_entry(source_id) do |updates|
          expect(updates[:expression_attribute_values]).to include(
            ':author_email' => author_email
          )
        end
      end

      it 'sets a version key made up of the start time of the ' \
         'current build, repeated twice' do
        history.write_entry(source_id) do |updates|
          expect(updates[:key]).to include(
            version_key: "#{start_time}_#{start_time}"
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

    it 'queries the dynamo table specified in config' do
      described_class.new(config, build).last_entry

      expect(dynamo_client).to have_received(:query)
        .with(hash_including(table_name: dynamo_table))
    end

    it 'sorts the results with newest items first' do
      described_class.new(config, build).last_entry

      expect(dynamo_client).to have_received(:query)
        .with(hash_including(scan_index_forward: false))
    end

    context 'when the build was launched by Retry command' do
      before do
        allow(build).to receive(:launched_by_retry?).and_return(true)
      end

      context 'when build is for a pr,' do
        before { allow(build).to receive(:for_pr?).and_return(true) }

        it 'queries using the commit hash, project code, and source version ' \
           'of the build' do
          described_class.new(config, build).last_entry

          expected_attr_values = {
            ':commit_hash' => commit_hash,
            ':project_code' => project_code,
            ':source_ref' => source_version
          }

          expect(dynamo_client).to have_received(:query).with(
            hash_including(expression_attribute_values: expected_attr_values)
          )
        end
      end

      context 'when build not is for a pr,' do
        before { allow(build).to receive(:for_pr?).and_return(false) }

        it 'queries using the commit hash and project code of the build, ' \
           'and a source ref starting with "build/"' do
          described_class.new(config, build).last_entry

          expected_attr_values = {
            ':commit_hash' => commit_hash,
            ':project_code' => project_code,
            ':source_ref' => 'branch/'
          }

          expect(dynamo_client).to have_received(:query).with(
            hash_including(expression_attribute_values: expected_attr_values)
          )
        end
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

      it 'queries using the commit hash and project code from the build' do
        described_class.new(config, build).last_entry

        expected_attr_values = { ':source_id' => source_id }

        expect(dynamo_client).to have_received(:query).with(
          hash_including(expression_attribute_values: expected_attr_values)
        )
      end

      it 'returns nil when no result is found' do
        expect(described_class.new(config, build).last_entry).to be_nil
      end

      context 'when a result is found,' do
        let(:value) { 'some_value' }

        let(:query_results) do
          Hashie::Mash.new(items: [{ attr: value }])
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
  end
end
