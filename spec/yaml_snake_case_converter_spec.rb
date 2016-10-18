require 'yaml_snake_case_converter'

describe YamlSnakeCaseConverter do
  before(:each) do
    @converter = YamlSnakeCaseConverter.new
  end

  describe '#convert_yaml_keys' do
    context 'yaml with keys with underscores' do
      it 'yaml with keys in camel case' do

        yaml_with_underscore = <<END
---
uncle_freddie: wilma
other_stuff: moo
fine: value
END

        expected_yaml_in_camel = <<END
---
uncleFreddie: wilma
otherStuff: moo
fine: value
END

        actual_yaml_in_camel = @converter.convert_yaml_keys yaml_with_underscore

        expect(actual_yaml_in_camel).to eq expected_yaml_in_camel
      end
    end
  end


  describe '#convert_snake_case_to_camel' do
    context 'string in snake case with a few underscores' do
      it 'returns camel case string' do
        underscore_name = 'this_is_not_a_string'

        expect(@converter.convert_snake_case_to_camel(underscore_name)).to eq 'thisIsNotAString'
      end
    end

    context 'string with no underscores' do
      it 'returns camel case string' do
        underscore_name = 'this'

        expect(@converter.convert_snake_case_to_camel(underscore_name)).to eq 'this'
      end
    end
  end
end
