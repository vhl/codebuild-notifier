describe CodeBuildNotifier::SlackMessage do
  let(:author_email) { 'velma@dinkley.org' }
  let(:author_name) { 'Velma Dinkley' }
  let(:build_id) { "#{project_code}:123" }
  let(:commit_hash) { 'b2ec4811171dc0755fff2a13f1d547e77c5bb0d6' }
  let(:commit_subject) { 'Patch holes in van' }
  let(:committer_email) { 'daphne@blake.org' }
  let(:git_repo) { 'https://my_host/my_repo' }
  let(:project_code) { 'codebuild-ruby2.5' }
  let(:region) { 'us-east-99' }
  let(:short_hash) { commit_hash[0..6] }
  let(:source_id) { "#{project_code}:#{trigger}" }
  let(:source_ref) { 'pr/1234' }
  let(:status) { 'FAILED' }

  let(:build) do
    instance_double(
      CodeBuildNotifier::CurrentBuild,
      build_id: build_id,
      commit_hash: commit_hash,
      git_repo_url: git_repo,
      project_code: project_code,
      status: status
    )
  end

  let(:config) do
    instance_double(
      CodeBuildNotifier::Config,
      region: region
    )
  end

  let(:message) { described_class.new(build, config, source_ref) }

  describe '#recipients' do
    it 'returns author email and commiter email if they are different' do
      allow(CodeBuildNotifier::Git).to receive(:current_commit).and_return(
        [short_hash, author_name, author_email, committer_email, commit_subject]
      )

      expect(message.recipients).to eq([author_email, committer_email])
    end

    it 'returns only one value if author email and commiter email are equal ' do
      allow(CodeBuildNotifier::Git).to receive(:current_commit).and_return(
        [short_hash, author_name, author_email, author_email, commit_subject]
      )

      expect(message.recipients).to eq([author_email])
    end
  end

  describe '#additional_channel' do
    it 'returns false if build is for a Pull Request' do
      allow(build).to receive(:for_pr?).and_return(true)

      expect(message.additional_channel).to be_falsey
    end

    context 'when the build is not for a Pull Request,' do
      before do
        allow(build).to receive(:for_pr?).and_return(false)
      end

      it 'is falsey if no additional channel is set in the config' do
        allow(config).to receive(:additional_channel).and_return(nil)

        expect(message.additional_channel).to be_falsey
      end

      it 'returns the additional channel in the config is one is set' do
        channel = '#mychannel'
        allow(config).to receive(:additional_channel).and_return(channel)

        expect(message.additional_channel).to eq(channel)
      end
    end
  end

  describe '#payload' do
    before do
      allow(CodeBuildNotifier::Git).to receive(:current_commit).and_return(
        [short_hash, author_name, author_email, committer_email, commit_subject]
      )
    end

    it 'includes the name of the commit author in the fallback and title keys' do
      expect(
        [message.payload[:fallback], message.payload[:title]]
      ).to all(include(author_name))
    end

    it 'includes a link to the build in the AWS console in the ' \
       'fallback and title keys' do
      link = "codebuild/projects/#{project_code}/build/#{build_id}/log"
      expect(
        [message.payload[:fallback], message.payload[:title]]
      ).to all(include(link))
    end

    it 'includes a link to the git commit in the fallback and text keys' do
      expect(
        [message.payload[:fallback], message.payload[:text]]
      ).to all(include("#{git_repo}/commit/#{commit_hash}|#{short_hash}"))
    end

    it 'includes the commit subject in the fallback and text keys' do
      expect(
        [message.payload[:fallback], message.payload[:text]]
      ).to all(include(commit_subject))
    end

    it 'includes the source_ref specified on initialize in the fallback and ' \
       'text keys' do
      message = described_class.new(build, config, source_ref)
      expect(
        [message.payload[:fallback], message.payload[:text]]
      ).to all(include(source_ref))
    end

    context 'when the build succeeded,' do
      before do
        allow(build).to receive(:status).and_return('SUCCEEDED')
      end

      it 'sets the value of the color key to the success color' do
        expect(message.payload[:color]).to eq('good')
      end

      it 'adds the success icon to the fallback and title keys' do
        expect(
          [message.payload[:fallback], message.payload[:title]]
        ).to all(include(':green_heart:'))
      end

      it 'includes the success status in the fallback and title keys' do
        expect(
          [message.payload[:fallback], message.payload[:title]]
        ).to all(include('succeeded'))
      end
    end

    context 'when the build failed,' do
      before do
        allow(build).to receive(:status).and_return('FAILED')
      end

      it 'sets the value of the color key to the failure color' do
        expect(message.payload[:color]).to eq('danger')
      end

      it 'adds the failure icon to the fallback and title keys' do
        expect(
          [message.payload[:fallback], message.payload[:title]]
        ).to all(include(':broken_heart:'))
      end

      it 'includes the failed status in the fallback and title keys' do
        expect(
          [message.payload[:fallback], message.payload[:title]]
        ).to all(include('failed'))
      end
    end

    context 'when the build is for a Pull Request,' do
      let(:pr_number) { '123' }
      let(:message) { described_class.new(build, config, "pr/#{pr_number}") }

      it 'includes a link to the Pull Request in the fallback and text keys' do
        expect(
          [message.payload[:fallback], message.payload[:text]]
        ).to all(include("#{git_repo}/pull/#{pr_number}"))
      end
    end

    context 'when the build is for a branch,' do
      let(:branch) { 'my_branch' }
      let(:message) { described_class.new(build, config, "branch/#{branch}") }

      it 'includes a link to the branch in the fallback and text keys' do
        expect(
          [message.payload[:fallback], message.payload[:text]]
        ).to all(include("#{git_repo}/tree/#{branch}"))
      end
    end
  end
end
