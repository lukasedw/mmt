require 'faker'

FactoryBot.define do
  # This is a valid factory, used to test to make sure all the factories
  # that use all_required_fields will work
  factory :collection_draft_all_required_fields, class: CollectionDraft do
    draft_type { 'CollectionDraft' }
    native_id { 'required_fields_draft_id' }
    provider_id { 'MMT_2' }
    draft { all_required_fields }
  end

  factory :collection_draft, class: CollectionDraft do
    # Empty draft
    provider_id { 'MMT_2' }
    draft_type { 'CollectionDraft' }
    draft { {} }
  end

  factory :mmt_1_collection_draft, class: CollectionDraft do
    provider_id { 'MMT_1' }
    draft_type { 'CollectionDraft' }
    draft { {} }
  end

  factory :full_collection_draft, class: CollectionDraft do
    transient do
      draft_short_name { nil }
      draft_entry_title { nil }
      version { nil }
      collection_data_type { nil }
    end

    native_id { 'full_collection_draft_id' }
    provider_id { 'MMT_2' }
    draft_type { 'CollectionDraft' }
    entry_title { draft_entry_title }
    short_name { draft_short_name }

    trait :with_valid_dates do
      draft do
        {
          'MetadataDates' => [{
            'Type' => 'CREATE',
            'Date' => '2010-12-25T00:00:00Z'
          }, {
            'Type' => 'UPDATE',
            'Date' => '2010-12-30T00:00:00Z'
          }]
        }
      end
    end

    draft do
      collection_one.merge(
        'ShortName'          => draft_short_name || "#{Faker::Number.number(digits: 6)}_#{Faker::Superhero.name}",
        'Version'            => version || '1',
        'EntryTitle'         => draft_entry_title || "#{Faker::Number.number(digits: 6)}_#{Faker::Job.title}",
        'CollectionDataType' => collection_data_type || 'SCIENCE_QUALITY'
      )
    end
  end

  factory :collection_draft_some_keywords_that_match_recommendations, class: CollectionDraft do
    draft_type { 'CollectionDraft' }
    native_id { 'gkr_already_contains_recommendations_draft_id' }
    provider_id { 'MMT_2' }
    draft do
      all_required_fields.merge(
        'ScienceKeywords' => [
          {
          'Category' => 'EARTH SCIENCE',
          'Topic' => 'OCEANS',
          'Term' => 'SALINITY/DENSITY'
          },
          {
          'Category' => 'EARTH SCIENCE',
          'Topic' => 'OCEANS',
          'Term' => 'OCEAN TEMPERATURE'
          }
        ]
      )
    end
  end

  factory :collection_draft_all_keywords_that_match_recommendations, class: CollectionDraft do
    draft_type { 'CollectionDraft' }
    native_id { 'gkr_already_contains_recommendations_draft_id' }
    provider_id { 'MMT_2' }
    draft do
      all_required_fields.merge(
        'ScienceKeywords' => [
          {
          'Category' => 'EARTH SCIENCE',
          'Topic' => 'OCEANS',
          'Term' => 'SALINITY/DENSITY'
          },
          {
          'Category' => 'EARTH SCIENCE',
          'Topic' => 'OCEANS',
          'Term' => 'OCEAN TEMPERATURE'
          },
          {
          'Category' => 'EARTH SCIENCE',
          'Topic' => 'OCEANS',
          'Term' => 'OCEAN CHEMISTRY'
          },
          {
          'Category' => 'EARTH SCIENCE',
          'Topic' => 'OCEANS',
          'Term' => 'OCEAN OPTICS'
          }
        ]
      )
    end
  end

  factory :collection_draft_that_will_not_generate_keyword_recommendations, class: CollectionDraft do
    # the abstract used here initially returned a response with no recommendations
    # that seems to have been subsequently fixed (with recommendations that seem
    # somewhat off), but we need to test for an response with no recommendations
    # so keeping this abstract until a better one for no recommendations is found
    draft_type { 'CollectionDraft' }
    native_id { 'gkr_already_contains_recommendations_draft_id' }
    provider_id { 'MMT_2' }
    draft do
      all_required_fields.merge(
        'Abstract' => 'This dataset consists of: (1) a suite of sedimentary rocks (primarily sandstones, with subordinate mudstones, conglomerates, glauconites and volcanic ashes) collected from Cretaceous through Paleogene strata of the Larsen basin, Antarctic Peninsula, and (2) geochronology and geochemistry data from some of the aforementioned samples. The collection and analysis of samples in this growing database were funded by'
      )
    end
  end
end
