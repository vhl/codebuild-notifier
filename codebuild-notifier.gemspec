lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'codebuild-notifier/version'

Gem::Specification.new do |spec|
  spec.name        = 'codebuild-notifier'
  spec.version     = CodeBuildNotifier::VERSION
  spec.authors     = ['VHL Ops Team']
  spec.email       = ['ops@vistahigherlearning.com']
  spec.summary     = 'Slack notifications for CodeBuild jobs.'
  spec.description = 'CodeBuild Notifier tracks the past status of CI jobs ' \
                     'run on AWS CodeBuild for each pr or whitelisted branch' \
                     'for a given project, and sends slack notifications ' \
                     'when a branch/pr changes build status.'
  spec.homepage    = 'https://github.com/vhl/codebuild-notifier'
  spec.executables = ['update-build-status']

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  unless spec.respond_to?(:metadata)
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end
  spec.metadata['allowed_push_host'] = 'push.fury.io'

  spec.files = `git ls-files -z`.split("\x0").reject do |file|
    file.match(%r{^(test|spec|features)/})
  end

  spec.add_dependency 'activesupport', '> 2.0', '< 6.0'
  spec.add_dependency 'aws-sdk-dynamodb', '~> 1.16'
  spec.add_dependency 'aws-sdk-secretsmanager', '~> 1.19'
  spec.add_dependency 'hashie', '> 1.0', '< 4.0'
  spec.add_dependency 'slack-ruby-client', '~> 0.13'

  spec.add_development_dependency 'rubocop', '0.58.2'
end
