require 'yaml'

class YamlSnakeCaseConverter

  def convert_yaml_keys(yaml)
    yaml_hash = YAML.load yaml
    output_hash = {}
    yaml_hash.each do |k, v|
      output_hash[convert_snake_case_to_camel(k)] = v
    end
    output_hash.to_yaml
  end

  def convert_snake_case_to_camel(input_string)
    output_string = input_string.gsub( /_./ ) do |underscore_with_next_char|
      underscore_with_next_char.gsub(/_/,'').upcase
    end

    output_string.chomp
  end
end