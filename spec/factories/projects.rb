FactoryBot.define do
  factory :project do
    sequence(:name, 'abc') { |n| "#{Faker::App.name}_#{n}" }
    description { Faker::Company.catch_phrase }
    homepage { Faker::Internet.domain_name }
    sequence(:identifier, '000') { |n| "#{name.underscore.gsub(' ', '_')}_#{n}" }
    is_public { true }
    status { 1 }
    after(:create) do |project|
      project.enabled_modules.create name: :redmine_hourglass
    end

    trait :with_tracker do
      after(:create) do |project|
        project.trackers << create(:tracker)
      end
    end
  end
end
