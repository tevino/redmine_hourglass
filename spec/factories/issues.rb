FactoryBot.define do
  factory :issue_priority do
    name { Faker::Color.color_name }
  end

  factory :issue_status do
    name { Faker::Adjective.negative }
    # description { Faker::Lorem.words(number: 10) } # note: not in Redmine <5.x
  end

  factory :tracker do
    name { Faker::Ancient.name }
    # description { Faker::Lorem.words(number: 10) } # note: not in Redmine <5.x
    default_status { create :issue_status }
  end

  factory :issue do
    project { create(:project, trackers: [(create :tracker)]) }
    author { create :user }
    subject { "Not working on #{Faker::Computer.os}" }
    description { Faker::Lorem.words(number: 10) }
    tracker { project.trackers.first }
    priority { create :issue_priority }
  end
end
