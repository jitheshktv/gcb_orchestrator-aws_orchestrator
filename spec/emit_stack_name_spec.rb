describe 'emit_stack_name' do
  context 'missing argument' do
    it 'fails out' do
      result = system 'bin/emit_stack_name'

      expect(result).to eq false
    end
  end

  context 'not dsl.rb or json' do
    it 'fails out' do
      result = system 'bin/emit_stack_name fred.txt'

      expect(result).to eq false
    end
  end

  context 'malformed argument with dsl ending' do
    it 'fails out' do
      result = system 'bin/emit_stack_name 20databaserdsbase_dsl.rb'

      expect(result).to eq false
    end
  end

  context 'malformed argument with json ending' do
    it 'fails out' do
      result = system 'bin/emit_stack_name 20databaserdsbase.json'

      expect(result).to eq false
    end
  end

  context 'properly formed dsl filename' do
    it 'prints the stack name' do
      stdout = `bin/emit_stack_name 20_database_rds_base_dsl.rb`

      expect(stdout).to eq "database-rdsbase\n"
    end
  end

  context 'properly formed json filename' do
    it 'prints the stack name' do
      stdout = `bin/emit_stack_name 20_database_rds_base.json`

      expect(stdout).to eq "database-rdsbase\n"
    end
  end
end
