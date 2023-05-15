# codebuild-notifier
# Copyright © 2018 Adam Alboyadjian <adam@cassia.tech>
# Copyright © 2018 Vista Higher Learning, Inc.
#
# codebuild-notifier is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later version.
#
# codebuild-notifier is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with codebuild-notifier.  If not, see <http://www.gnu.org/licenses/>.

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
  spec.licenses    = ['GPL-3.0+']
  spec.homepage    = 'https://github.com/vhl/codebuild-notifier'
  spec.executables = ['update-build-status']

  spec.files = `git ls-files -z`.split("\x0").reject do |file|
    file.match(%r{^(test|spec|features)/})
  end

  spec.add_dependency 'activesupport', '~> 6.1.7.3'
  spec.add_dependency 'aws-sdk-dynamodb', '~> 1.16'
  spec.add_dependency 'aws-sdk-secretsmanager', '~> 1.19'
  spec.add_dependency 'hashie', '> 1.0', '< 4.0'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'slack-ruby-client', '~> 0.13'

  spec.add_development_dependency 'rspec', '~> 3.8'
  spec.add_development_dependency 'rubocop', '0.58.2'
  spec.add_development_dependency 'rubocop-rspec', '1.30.0'
  spec.add_development_dependency 'simplecov', '~> 0.16'
end
