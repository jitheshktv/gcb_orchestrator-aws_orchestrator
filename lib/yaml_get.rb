require 'yaml'
require 'ruby_dig' if RUBY_VERSION < "2.3.0"

class YamlGetter

  def get(yaml:, yaml_path:)
    yaml_hash = YAML.load yaml
    path_components = yaml_path.split('/')
    sub_hash = yaml_hash.dig(*path_components)

    if sub_hash.nil?
      raise "#{yaml_path} not found in #{yaml}"
    else
      return sub_hash
    end
  end
end
