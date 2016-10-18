describe 'get_run_list' do
  context 'manifest is empty' do
    # this is a bad test - any failure will print out nothing to stdout most likely
    it 'prints nothing' do
      stdout = `bin/get_run_list spec/tech_stacks/empty_manifest.yml run_list`

      expect(stdout).to eq ''
    end
  end

  context 'manifest has elements' do
    it 'prints the elements separated by space' do
      stdout = `bin/get_run_list spec/tech_stacks/sawgrass_sample_manifest.yml run_list`

      expect(stdout).to eq '60_server_tibco-bw_dsl.rb=chef_cookbook=sawgrass-tibco-bw 10_database_sawgrass.json=oracle_script=main.sql 20_security_sawgrass_dsl.rb=='
    end
  end
end
