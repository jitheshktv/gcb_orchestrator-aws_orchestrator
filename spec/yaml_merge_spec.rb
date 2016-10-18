require 'yaml_merge'

describe 'yaml_merge cli' do
  context 'one environment key with common_parameters subkey' do
    it 'return yaml for env/common' do

      actual_merged_yaml = `bin/yaml_merge spec/yaml_merge_test_yml/yaml1.yml spec/yaml_merge_test_yml/yaml2.yml`

      expected_merged_yaml = <<END
---
environment:
  name: dev
  common_parameters:
    vpc_id: vpc-1234
foo:
  cow: dev
END

      expect(actual_merged_yaml).to eq expected_merged_yaml
    end
  end

  # context
end

describe YamlMerger do
  context 'collision' do
    it 'raises an error' do

      hash1 = {
        'key1' => 'moo',
        'key2' => 'cow'
      }

      hash2 = {
        'key1' => 'moo1',
        'key3' => 'cow'
      }
      merger = YamlMerger.new

      expect {
        merger.merge(hash1.to_yaml, hash2.to_yaml)
      }.to raise_error 'Collision on key: key1 for moo v. moo1'
    end
  end

  context 'no collision' do
    it 'return merged hash' do

      hash1 = {
        'key1' => 'moo',
        'key2' => 'cow'
      }

      hash2 = {
        'key3' => 'moo1',
        'key4' => 'cow'
      }
      merger = YamlMerger.new

      expected_merged_yaml = <<END
---
key1: moo
key2: cow
key3: moo1
key4: cow
END
      actual_merged_yaml = merger.merge(hash1.to_yaml, hash2.to_yaml)
      expect(actual_merged_yaml).to eq expected_merged_yaml
    end
  end
end
