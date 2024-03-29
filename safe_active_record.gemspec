# frozen_string_literal: true

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

Gem::Specification.new do |s|
  s.name        = 'safe_active_record'
  s.version     = '0.1.0'
  s.summary     = 'Security middleware to defend against SQL injection in Active Record.'
  s.description = s.summary
  s.authors     = ['Shuyang Wang', 'Sam Marder', 'Camille Schneider']
  s.files       = Dir['lib/**/*.rb']
  s.license     = 'Apache-2.0'
  s.metadata['rubygems_mfa_required'] = 'true'
end
