describe CodeBuildNotifier::Config do
  describe '#slack_admins' do
    it 'returns single element array if a value with no commas is specified' do
      user = 'frank'
      config = described_class.new(slack_admins: user)
      expect(config.slack_admins).to eq [user]
    end

    it 'returns a multi-element array if a value with commas is specified' do
      users = %w[frank dino]
      config = described_class.new(slack_admins: users.join(','))
      expect(config.slack_admins).to eq users
    end

    it 'returns an empty array if no value is specified' do
      config = described_class.new(slack_admins: nil)
      expect(config.slack_admins).to eq []
    end
  end

  describe '#whitelist_branches' do
    it 'returns single element array if a value with no commas is specified' do
      branch = 'oak'
      config = described_class.new(whitelist_branches: branch)
      expect(config.whitelist_branches).to eq [branch]
    end

    it 'returns a multi-element array if a value with commas is specified' do
      branches = %w[oak elm]
      config = described_class.new(whitelist_branches: branches.join(','))
      expect(config.whitelist_branches).to eq branches
    end

    it 'returns an array of default values if no value is specified' do
      config = described_class.new(whitelist_branches: nil)
      expect(config.whitelist_branches).to eq described_class::DEFAULT_WHITELIST
    end
  end

  describe '#non_pr_branch_ids' do
    it 'prepends each whitelist branch with "branch/"' do
      branches = %w[oak elm]
      config = described_class.new(whitelist_branches: branches.join(','))
      expect(config.non_pr_branch_ids).to eq %w[branch/oak branch/elm]
    end
  end

  describe '#whitelist' do
    it 'returns a comma-separated string of branch names' do
      branches = %w[oak elm]
      config = described_class.new(whitelist_branches: branches.join(','))
      expect(config.whitelist).to eq 'oak, elm'
    end
  end
end
