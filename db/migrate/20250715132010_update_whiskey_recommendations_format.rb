class UpdateWhiskeyRecommendationsFormat < ActiveRecord::Migration[8.0]
  def change
    # Add a new column for structured whiskey recommendations in JSON format
    add_column :presentations, :whiskey_recommendations_json, :jsonb, default: []
    
    # Add indexes for JSON queries if needed
    add_index :presentations, :whiskey_recommendations_json, using: :gin
  end
end
