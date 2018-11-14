describe CodeBuildNotifier::Git do
  describe '.current_commit' do
    it 'returns an array of values returned by calling git show, split ' \
       'on the | character' do
      git_output = 'a|b|c|d'
      allow(described_class).to receive(:`).and_return("#{git_output}\n")

      expect(described_class.current_commit).to eq %w[a b c d]
    end
  end
end
