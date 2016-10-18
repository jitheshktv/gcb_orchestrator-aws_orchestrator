require 'yaml'
require 'ruby_dig' if RUBY_VERSION < "2.3.0"

class YamlCutter

  def cut(yaml:, yaml_path:)
    yaml_hash = YAML.load yaml
    path_components = yaml_path.split('/')
    sub_hash = yaml_hash.dig(*path_components)

    if sub_hash.is_a? Hash
      sub_hash.to_yaml
    else
      raise "Not expecting a leaf node in the yaml #{sub_hash.class}"
    end
  end
end
