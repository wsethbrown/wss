class PresentationsController < ApplicationController
  before_action :set_presentation, only: [:show, :edit, :update, :destroy]

  def index
    # Static presentation data
    @all_presentations = [
      {
        id: 1,
        title: "Introduction to Scotch Whisky",
        category: "Scotch Whisky",
        duration: "45 min",
        difficulty: "Beginner",
        rating: 4.8,
        reviews: 127,
        price: "$9.99",
        image: "scotch-intro",
        description: "Perfect for beginners, this presentation covers the basics of Scotch whisky production, regions, and tasting techniques."
      },
      {
        id: 2,
        title: "Bourbon: America's Native Spirit",
        category: "Bourbon",
        duration: "60 min",
        difficulty: "Intermediate",
        rating: 4.9,
        reviews: 89,
        price: "$12.99",
        image: "bourbon-guide",
        description: "Explore the rich history and production methods of America's favorite whiskey, from mash bills to barrel aging."
      },
      {
        id: 3,
        title: "Japanese Whisky Masterclass",
        category: "Japanese Whisky",
        duration: "75 min",
        difficulty: "Advanced",
        rating: 4.7,
        reviews: 156,
        price: "$14.99",
        image: "japanese-whisky",
        description: "Discover the unique characteristics and craftsmanship behind Japan's world-renowned whisky tradition."
      },
      {
        id: 4,
        title: "Irish Whiskey Traditions",
        category: "Irish Whiskey",
        duration: "50 min",
        difficulty: "Beginner",
        rating: 4.6,
        reviews: 94,
        price: "$10.99",
        image: "irish-traditions",
        description: "From triple distillation to pot still whiskey, learn about Ireland's centuries-old whiskey heritage."
      },
      {
        id: 5,
        title: "Rye Whiskey Renaissance",
        category: "Rye Whiskey",
        duration: "55 min",
        difficulty: "Intermediate",
        rating: 4.5,
        reviews: 67,
        price: "$11.99",
        image: "rye-renaissance",
        description: "Explore the spicy, bold flavors of rye whiskey and its resurgence in modern craft distilling."
      },
      {
        id: 6,
        title: "Canadian Whisky Deep Dive",
        category: "Canadian Whisky",
        duration: "40 min",
        difficulty: "Beginner",
        rating: 4.4,
        reviews: 43,
        price: "$9.99",
        image: "canadian-deep-dive",
        description: "Learn about the smooth, approachable style of Canadian whisky and its unique production methods."
      },
      {
        id: 7,
        title: "Peated Scotch Exploration",
        category: "Scotch Whisky",
        duration: "70 min",
        difficulty: "Advanced",
        rating: 4.8,
        reviews: 112,
        price: "$13.99",
        image: "peated-scotch",
        description: "Dive deep into the smoky, peaty world of Islay and other peated Scotch whiskies."
      },
      {
        id: 8,
        title: "Single Barrel Bourbon Tasting",
        category: "Bourbon",
        duration: "65 min",
        difficulty: "Advanced",
        rating: 4.9,
        reviews: 78,
        price: "$15.99",
        image: "single-barrel",
        description: "Master the art of single barrel bourbon tasting and understand what makes each barrel unique."
      },
      {
        id: 9,
        title: "Whiskey & Food Pairing",
        category: "Beginner",
        duration: "80 min",
        difficulty: "Intermediate",
        rating: 4.7,
        reviews: 134,
        price: "$16.99",
        image: "food-pairing",
        description: "Learn how to pair different whiskey styles with food to enhance both the drink and the meal."
      },
      {
        id: 10,
        title: "Craft Distillery Tour",
        category: "Beginner",
        duration: "45 min",
        difficulty: "Beginner",
        rating: 4.6,
        reviews: 89,
        price: "$8.99",
        image: "craft-distillery",
        description: "Take a virtual tour of craft distilleries and learn about small-batch whiskey production."
      },
      {
        id: 11,
        title: "Vintage Whiskey Appreciation",
        category: "Advanced",
        duration: "90 min",
        difficulty: "Advanced",
        rating: 4.9,
        reviews: 45,
        price: "$19.99",
        image: "vintage-appreciation",
        description: "Explore vintage and rare whiskies, understanding what makes them special and valuable."
      },
      {
        id: 12,
        title: "Whiskey Cocktail Classics",
        category: "Beginner",
        duration: "60 min",
        difficulty: "Beginner",
        rating: 4.5,
        reviews: 156,
        price: "$11.99",
        image: "cocktail-classics",
        description: "Learn to make classic whiskey cocktails and understand how different styles work in mixed drinks."
      }
    ]

    # Filter by search term
    if params[:search].present?
      search_term = params[:search].downcase
      @all_presentations = @all_presentations.select do |presentation|
        presentation[:title].downcase.include?(search_term) ||
        presentation[:description].downcase.include?(search_term) ||
        presentation[:category].downcase.include?(search_term)
      end
    end

    # Filter by category
    if params[:category].present?
      @all_presentations = @all_presentations.select do |presentation|
        presentation[:category] == params[:category]
      end
    end

    # Sort by popularity (rating) by default, or by other criteria
    case params[:sort]
    when 'newest'
      @all_presentations = @all_presentations.sort_by { |p| p[:id] }.reverse
    when 'rating'
      @all_presentations = @all_presentations.sort_by { |p| p[:rating] }.reverse
    when 'duration'
      @all_presentations = @all_presentations.sort_by { |p| p[:duration].to_i }
    else # 'popular' - default
      @all_presentations = @all_presentations.sort_by { |p| p[:rating] }.reverse
    end

    @presentations = @all_presentations
  end

  def show
    # For now, we'll use static data for the show page
    @presentation = {
      id: params[:id],
      title: "Introduction to Scotch Whisky",
      category: "Scotch Whisky",
      duration: "45 min",
      difficulty: "Beginner",
      rating: 4.8,
      reviews: 127,
      price: "$9.99",
      description: "Perfect for beginners, this comprehensive presentation covers the basics of Scotch whisky production, regions, and tasting techniques."
    }
  end

  def new
    @presentation = Presentation.new
    authorize @presentation
  end

  def create
    @presentation = current_user.presentations.build(presentation_params)
    authorize @presentation

    if @presentation.save
      redirect_to @presentation, notice: 'Presentation was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @presentation
  end

  def update
    authorize @presentation

    if @presentation.update(presentation_params)
      redirect_to @presentation, notice: 'Presentation was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @presentation

    @presentation.destroy
    redirect_to presentations_url, notice: 'Presentation was successfully deleted.'
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:id])
  end

  def presentation_params
    params.require(:presentation).permit(:title, :description, :content, :price, :category)
  end
end
