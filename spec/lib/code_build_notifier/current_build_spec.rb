describe CodeBuildNotifier::CurrentBuild do
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
    it 'joins the project code and trigger with a colon' do
      project_code = 'abc'
      build_id = "#{project_code}:123"
      build = described_class.new(build_id: build_id, trigger: 'pr/143')

      expect(build.source_id).to eq('abc:pr/143')
    end
  end
end
