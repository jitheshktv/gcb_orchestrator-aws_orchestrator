require 'local_role'

describe LocalRole do

  before(:each) do
    @local_role = LocalRole.new
  end

  describe '#discover' do
    context 'running locally' do

      it 'returns the magic string local-non-ec2' do
        actual_role = @local_role.discover

        expect(actual_role).to eq 'local-non-ec2'
      end
    end

    # too tricky to spend the time on
    # context 'running on ec2 with a role', :ec2_only do
    #
    #   it 'returns the role name' do
    #   end
    # end
    #
    # context 'running on ec2 without a role', :ec2_only do
    #   it 'raises an error' do
    #   end
    # end
  end
end
