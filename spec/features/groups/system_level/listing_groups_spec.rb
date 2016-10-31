# MMT-561
require 'rails_helper'

describe 'Listing System Level Groups' do
  context 'when viewing the index page with a mix of system level and provider level groups' do
    before do
      login(admin: true)

      # stub for index groups / get_cmr_groups with a mix of groups
      index_groups_response = Cmr::Response.new(Faraday::Response.new(status: 200, body: JSON.parse(File.read('spec/fixtures/groups/sys_groups_index.json'))))
      allow_any_instance_of(Cmr::CmrClient).to receive(:get_cmr_groups).and_return(index_groups_response)

      visit groups_path
    end

    it 'displays the groups table with the group information' do
      within '.groups-table' do
        within all('tr')[1] do
          expect(page).to have_content('LARC Test Group 01 LARC 5')
        end
        within all('tr')[2] do
          expect(page).to have_content('SEDAC Test Group 02 SEDAC 0')
        end
        within all('tr')[3] do
          expect(page).to have_content('Administrators SYS CMR 6')
          expect(page).to have_css('span.eui-badge--sm')
        end
        within all('tr')[4] do
          expect(page).to have_content('Administrators_2 SYS CMR 2')
          expect(page).to have_css('span.eui-badge--sm')
        end
        within all('tr')[5] do
          expect(page).to have_content('CH mmt2 test system group 03 MMT_2 4')
        end
      end
    end
  end
end
