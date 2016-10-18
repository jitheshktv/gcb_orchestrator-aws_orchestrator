describe 'list_tech_stacks' do
  context 'manifest is empty' do
    # this is a bad test - any failure will print out nothing to stdout most likely
    it 'prints nothing' do
      stdout = `bin/list_tech_stacks spec/tech_stacks/empty_manifest.yml`

      expect(stdout).to eq ''
    end
  end

  context 'manifest has elements' do
    it 'prints the elements separated by newline' do
      stdout = `bin/list_tech_stacks spec/tech_stacks/fred_wilma_manifest.yml`

      expect(stdout).to eq 'uncle_freddie wilma '
    end
  end
end
