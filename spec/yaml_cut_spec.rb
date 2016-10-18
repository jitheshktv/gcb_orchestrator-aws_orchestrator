require 'yaml'
require 'yaml_cut'

describe 'yaml_cut cli' do
  context 'one environment key with common_parameters subkey' do
    it 'return yaml for env/common' do

      result = `bin/yaml_cut spec/yaml_cut_test_yml/env.yml environment/common_parameters`
puts result
      expect(YAML.load(result)).to eq({
                                        'vpc_id' => 'vpc-1234'
                                      })
    end
  end

  # context
end

describe YamlCutter do
  context 'one environment key with common_parameters subkey' do
    it 'return yaml for env/common' do

      yaml_cutter = YamlCutter.new

      actual_cut_yaml = yaml_cutter.cut yaml: IO.read('spec/yaml_cut_test_yml/env.yml'),
                                        yaml_path: 'environment/common_parameters'

      expected_cut_yaml = <<END
---
vpc_id: vpc-1234
END
      expect(actual_cut_yaml).to eq expected_cut_yaml
    end
  end
end
