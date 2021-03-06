describe 'Service Options Form', js: true do
  before do
    login
    draft = create(:empty_service_draft, user: User.where(urs_uid: 'testuser').first)
    visit edit_service_draft_path(draft, 'options')
  end

  context 'when submitting the form' do
    before do
      within '.subset' do
        check 'Spatial Subset'
        within '.spatial-subset-fields' do
          check 'Point'
          within '.point-fields' do
            choose 'False'
          end

          check 'Polygon'
          within '.polygon-fields' do
            fill_in 'Maximum Number Of Points', with: 20
            choose 'True'
          end

          check 'Shapefile'
          within '.shapefile-fields' do
            within '.multiple-item-0' do
              select 'ESRI', from: 'Format'
              fill_in 'Maximum File Size In Bytes', with: 400
            end

            click_on 'Add another Shapefile'

            within '.multiple-item-1' do
              select 'GeoJSON', from: 'Format'
            end
          end
        end
      end

      select 'ANOMOLY', from: 'Variable Aggregation Supported Methods'

      within '.supported-input-projections .multiple-item-0' do
        select 'Geographic', from: 'Projection Name'
        fill_in 'Projection Latitude Of Center', with: 10
        fill_in 'Projection Longitude Of Center', with: 10
        fill_in 'Projection False Easting', with: 10
        fill_in 'Projection False Northing', with: 10
        fill_in 'Projection Authority', with: '4326'
        select 'Degrees', from: 'Projection Unit'
        select 'World Geodetic System (WGS) 1984', from: 'Projection Datum Name'
      end

      within '.multiple.supported-output-projections' do
        within '.multiple-item-0' do
          select 'Geographic', from: 'Projection Name'
          fill_in 'Projection Latitude Of Center', with: 10
          fill_in 'Projection Longitude Of Center', with: 10
          fill_in 'Projection False Easting', with: 10
          fill_in 'Projection False Northing', with: 10
          fill_in 'Projection Authority', with: '4326'
          select 'Degrees', from: 'Projection Unit'
          select 'World Geodetic System (WGS) 1984', from: 'Projection Datum Name'
        end

        click_on 'Add another Supported Output Projection'

        within '.multiple-item-1' do
          select 'NAD83 / UTM zone 17N', from: 'Projection Name'
          fill_in 'Projection Latitude Of Center', with: 10
          fill_in 'Projection Longitude Of Center', with: 10
          fill_in 'Projection False Easting', with: 10
          fill_in 'Projection False Northing', with: 10
          fill_in 'Projection Authority', with: '26917'
          select 'Meters', from: 'Projection Unit'
          select 'North American Datum (NAD) 1983', from: 'Projection Datum Name'
        end
      end

      select 'Bilinear Interpolation', from: 'Interpolation Types'
      select 'Bicubic Interpolation', from: 'Interpolation Types'

      fill_in 'Max Granules', with: 50

      within '.supported-reformattings' do
        select 'HDF-EOS2', from: 'Supported Input Format'
        select 'HDF-EOS2', from: 'Supported Output Formats'
        select 'HDF-EOS', from: 'Supported Output Formats'
      end

      within '.nav-top' do
        click_on 'Save'
      end

      within '.subset' do
        # MMT-2428: we want to follow the steps in the ticket to try to recreate the error.
        # 1. Check both Temporal and Variable Subsets and select a boolean value for both
        # 2. Uncheck both, re-check them, and select a value for just one of them
        # 3. If the bug persists, both radio group labels (despite one of them not having a T/F selected)
        #    will have required icons, otherwise only the radio group with a selected button
        #    will have a required icon
        check 'Variable Subset'
        check 'Temporal Subset'

        within '.variable-subset-fields' do
          choose 'True'
        end
        within '.temporal-subset-fields' do
          choose 'True'
        end

        uncheck 'Temporal Subset'
        uncheck 'Variable Subset'
        check 'Variable Subset'
        check 'Temporal Subset'
        within '.variable-subset-fields' do
          choose 'True'
        end
      end
    end

    it 'does not erroneously display required icons for Subset child fields' do
      within '.variable-subset-fields' do
        expect(page).to have_css('label.eui-required-o')
      end
      within '.temporal-subset-fields' do
        expect(page).to have_no_css('label.eui-required-o')
      end
    end

    it 'does not display required icons for accordions in Options section' do
      expect(page).to have_no_css('h3.eui-required-o.always-required')
    end

    it 'displays a confirmation message' do
      expect(page).to have_content('Service Draft Updated Successfully!')
    end

    context 'when viewing the form' do
      include_examples 'Options Form'
    end
  end
end
