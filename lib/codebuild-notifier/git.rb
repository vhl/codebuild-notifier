module CodeBuildNotifier
  module Git
    def current_commit
      `git show -s --format='%h|%aN|%aE|%cE|%s'`.chomp.split('|')
    end
    module_function :current_commit
  end
end
