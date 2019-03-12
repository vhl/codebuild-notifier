describe CodeBuildNotifier::CurrentBuild do
  let(:previous_branch_name) { 'previous_branch' }
  let(:previous_source_id) { 'previous:123' }
  let(:previous_source_ref) { 'refs/previous' }
  let(:previous_build) do
    Hashie::Mash.new(
      branch_name: previous_branch_name,
      source_id: previous_source_id,
      source_ref: previous_source_ref
    )
  end
  let(:author_email) { 'velma@dinkley.org' }
  let(:author_name) { 'Velma Dinkley' }
  let(:commit_subject) { 'Patch holes in van' }
  let(:committer_email) { 'daphne@blake.org' }
  let(:committer_name) { 'Daphne Blake' }
  let(:short_hash) { 'e397ece' }

  before do
    allow(CodeBuildNotifier::Git).to receive(:current_commit).and_return(
      [
        short_hash,
        author_name,
        author_email,
        committer_name,
        committer_email,
        commit_subject
      ]
    )
  end

  describe 'attributes from git' do
    let(:build) { described_class.new }

    specify { expect(build.author_email).to eq(author_email) }
    specify { expect(build.author_name).to eq(author_name) }
    specify { expect(build.commit_message_subject).to eq(commit_subject) }
    specify { expect(build.committer_email).to eq(committer_email) }
    specify { expect(build.committer_name).to eq(committer_name) }
    specify { expect(build.short_hash).to eq(short_hash) }
  end

  describe '#git_repo_url' do
    it 'removes .git from the end of a git repo specified with .git' do
      build = described_class.new(git_repo: 'https://my_host/my_repo.git')
      expect(build.git_repo_url).to eq('https://my_host/my_repo')
    end

    it 'returns a git repo specified without .git unchanged' do
      build = described_class.new(git_repo: 'https://my_host/my_repo')
      expect(build.git_repo_url).to eq('https://my_host/my_repo')
    end
  end

  describe '#branch_name' do
    context 'when launched by retry,' do
      it 'returns nil if no previous build is set' do
        build = described_class.new(trigger: nil)
        expect(build.branch_name).to be_nil
      end

      it 'returns the branch_name of the previous build if one is set' do
        build = described_class.new(trigger: nil)
        build.previous_build = previous_build
        expect(build.branch_name).to eq(previous_branch_name)
      end
    end

    context 'when not launched by retry,' do
      it 'returns empty string if head ref argument is nil' do
        build = described_class.new(trigger: 'abc', head_ref: nil)
        expect(build.branch_name).to eq('')
      end

      it 'returns empty string if head ref argument is empty string' do
        build = described_class.new(trigger: 'abc', head_ref: '')
        expect(build.branch_name).to eq('')
      end

      it 'returns the branch name without refs/heads prefix' do
        branch = 'mae-12345'
        ref = "refs/heads/#{branch}"
        build = described_class.new(trigger: 'abc', head_ref: ref)
        expect(build.branch_name).to eq(branch)
      end
    end
  end

  describe '#status' do
    it 'returns SUCCEEDED when status code is integer 1' do
      build = described_class.new(status_code: 1)
      expect(build.status).to eq('SUCCEEDED')
    end

    it 'returns SUCCEEDED when status code is string 1' do
      build = described_class.new(status_code: '1')
      expect(build.status).to eq('SUCCEEDED')
    end

    it 'returns FAILED when status code is not 1' do
      build = described_class.new(status_code: '0')
      expect(build.status).to eq('FAILED')
    end
  end

  describe '#project_code' do
    it 'returns the first element of the build_id' do
      build = described_class.new(build_id: 'abc:123')
      expect(build.project_code).to eq('abc')
    end
  end

  describe '#launched_by_retry?' do
    it 'is true if trigger is nil' do
      build = described_class.new(trigger: nil)
      expect(build).to be_launched_by_retry
    end

    it 'is true if trigger is an empty string' do
      build = described_class.new(trigger: '')
      expect(build).to be_launched_by_retry
    end

    it 'is false if trigger is not blank' do
      build = described_class.new(trigger: 'branch/ok')
      expect(build).not_to be_launched_by_retry
    end
  end

  describe '#for_pr?' do
    it 'is true if trigger starts with "pr/"' do
      expect(described_class.new(trigger: 'pr/100')).to be_for_pr
    end

    it 'is false if trigger contains, but does not start with "pr/"' do
      expect(described_class.new(trigger: 'branch/pr/100')).not_to be_for_pr
    end

    it 'is false if trigger is nil' do
      expect(described_class.new(trigger: nil)).not_to be_for_pr
    end

    it 'is false if trigger is empty string' do
      expect(described_class.new(trigger: '')).not_to be_for_pr
    end
  end

  describe '#source_id' do
    context 'when launched by retry,' do
      it 'returns nil if no previous build is set' do
        build = described_class.new(trigger: nil)
        expect(build.source_id).to be_nil
      end

      it 'returns the source_id of the previous build if one is set' do
        build = described_class.new(trigger: nil)
        build.previous_build = previous_build
        expect(build.source_id).to eq(previous_source_id)
      end
    end

    context 'when not launched by retry,' do
      it 'joins the project code and trigger with a colon' do
        project_code = 'abc'
        build_id = "#{project_code}:123"
        build = described_class.new(build_id: build_id, trigger: 'pr/143')

        expect(build.source_id).to eq('abc:pr/143')
      end
    end
  end

  describe '#source_ref' do
    context 'when launched by retry,' do
      it 'returns nil if no previous build is set' do
        build = described_class.new(trigger: nil)
        expect(build.source_ref).to be_nil
      end

      it 'returns the source_ref of the previous build if one is set' do
        build = described_class.new(trigger: nil)
        build.previous_build = previous_build
        expect(build.source_ref).to eq(previous_source_ref)
      end
    end

    context 'when not launched by retry,' do
      it 'returns the build trigger' do
        build = described_class.new(trigger: 'pr/143')

        expect(build.source_ref).to eq('pr/143')
      end
    end
  end
end
