require 'faker'

FactoryGirl.define do
  factory :full_collection_draft_proposal, class: CollectionDraftProposal do
    transient do
      draft_short_name 'ABC5918'
      draft_entry_title 'Entry Title'
      version '001'
      collection_data_type 'SCIENCE_QUALITY'
    end

    native_id 'full_collection_draft_proposal_id'
    provider_id 'MMT_2'
    draft_type 'CollectionDraftProposal'

    trait :with_valid_dates do
      draft {{
        'MetadataDates' => [{
          'Type' => 'CREATE',
          'Date' => '2010-12-25T00:00:00Z'
        }, {
          'Type' => 'UPDATE',
          'Date' => '2010-12-30T00:00:00Z'
        }]
      }}
    end

    draft {
      collection_draft_proposal_one.merge(
        'ShortName' => draft_short_name,
        'EntryTitle' => draft_entry_title,
        'Version' => version,
        'CollectionDataType' => collection_data_type
      )
    }
  end
end