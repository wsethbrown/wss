class Tag < ApplicationRecord
  has_many :user_tags, dependent: :destroy
  has_many :users, through: :user_tags

  validates :name, presence: true, uniqueness: true
  validates :color, presence: true, format: { with: /\A#[0-9A-F]{6}\z/i }
  validates :category, presence: true

  scope :by_category, ->(category) { where(category: category) }
  scope :whiskey, -> { where(category: "whiskey") }
  scope :interests, -> { where(category: "interests") }
  scope :skills, -> { where(category: "skills") }

  def self.create_default_tags
    whiskey_tags = [
      { name: "Bourbon", color: "#D97706", category: "whiskey", description: "American whiskey made from corn" },
      { name: "Scotch", color: "#DC2626", category: "whiskey", description: "Scottish malt whisky" },
      { name: "Rye", color: "#7C3AED", category: "whiskey", description: "Rye whiskey enthusiast" },
      { name: "Irish", color: "#059669", category: "whiskey", description: "Irish whiskey lover" },
      { name: "Japanese", color: "#DB2777", category: "whiskey", description: "Japanese whisky connoisseur" },
      { name: "Canadian", color: "#2563EB", category: "whiskey", description: "Canadian whisky fan" },
      { name: "Single Malt", color: "#B45309", category: "whiskey", description: "Single malt enthusiast" },
      { name: "Blended", color: "#7C2D12", category: "whiskey", description: "Blended whiskey appreciator" },
      { name: "Cask Strength", color: "#991B1B", category: "whiskey", description: "High-proof whiskey lover" },
      { name: "Peated", color: "#374151", category: "whiskey", description: "Smoky, peated whiskey fan" }
    ]

    interest_tags = [
      { name: "Collector", color: "#0F766E", category: "interests", description: "Whiskey bottle collector" },
      { name: "Tasting", color: "#BE123C", category: "interests", description: "Whiskey tasting enthusiast" },
      { name: "Distillery Tours", color: "#A16207", category: "interests", description: "Loves visiting distilleries" },
      { name: "Cocktails", color: "#7E22CE", category: "interests", description: "Whiskey cocktail enthusiast" },
      { name: "History", color: "#0369A1", category: "interests", description: "Whiskey history buff" },
      { name: "Investment", color: "#166534", category: "interests", description: "Whiskey investment focused" }
    ]

    skill_tags = [
      { name: "Sommelier", color: "#DC2626", category: "skills", description: "Certified whiskey sommelier" },
      { name: "Blogger", color: "#7C3AED", category: "skills", description: "Whiskey blogger/writer" },
      { name: "Distiller", color: "#B45309", category: "skills", description: "Professional distiller" },
      { name: "Bartender", color: "#059669", category: "skills", description: "Professional bartender" },
      { name: "Reviewer", color: "#DB2777", category: "skills", description: "Whiskey reviewer" },
      { name: "Educator", color: "#2563EB", category: "skills", description: "Whiskey educator" }
    ]

    [ whiskey_tags, interest_tags, skill_tags ].flatten.each do |tag_attrs|
      Tag.find_or_create_by(name: tag_attrs[:name]) do |tag|
        tag.assign_attributes(tag_attrs)
      end
    end
  end

  def display_name
    name.titleize
  end

  def user_count
    users.count
  end
end
