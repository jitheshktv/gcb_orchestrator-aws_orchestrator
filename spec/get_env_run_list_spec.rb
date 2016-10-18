describe 'get_env_run_list' do
  context 'manifest is empty' do
    # this is a bad test - any failure will print out nothing to stdout most likely
    it 'prints nothing' do
      stdout = `bin/get_run_list spec/environment/manifest_empty.yml run_list`

      expect(stdout).to eq ''
    end
  end

  context 'manifest has one tech_stack' do
    it 'prints the elements separated by space' do
      stdout = `bin/get_env_run_list spec/environment/manifest_single_stack.yml tech_stacks`

      expect(stdout).to eq 'gcb_tech_stack-sawgrass'
    end
  end

  context 'manifest has multiple tech_stacks' do
    it 'prints the elements separated by space' do
      stdout = `bin/get_env_run_list spec/environment/manifest_multi_stack.yml tech_stacks`

      expect(stdout).to eq 'gcb_tech_stack-dummy gcb_tech_stack-sawgrass'
    end
  end
end
