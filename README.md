# 🥃 Whiskey Share Society

A modern Rails platform for whiskey enthusiasts to discover, share, and savor whiskey together. Join exclusive clubs, RSVP to tastings, and access professional presentations to host world-class whiskey experiences.

![Whiskey Share Society](https://img.shields.io/badge/Rails-7.1+-red.svg)
![Ruby](https://img.shields.io/badge/Ruby-3.2+-red.svg)
![Tailwind CSS](https://img.shields.io/badge/Tailwind-3.3+-blue.svg)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-blue.svg)
![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)

## ✨ Features

### 🏠 **Home Page**
- **Full-width hero section** with modern glassmorphism design
- **Interactive "How it Works"** section with sticky scroll
- **Societies overview** with public/private club information
- **Pricing plans** with subscription tiers ($15.99/month, $12.99/quarterly, $10.99/yearly)

### 🏛️ **Societies**
- **Public & Private Societies** with different access levels
- **Role-based membership** (Admin, Officer, Member)
- **Application system** for private societies
- **Event coordination** and forum features
- **Search and filter** functionality

### 📚 **Presentations**
- **12 professional presentations** covering all whiskey types
- **Interactive search** with real-time filtering
- **Detailed modal views** with tasting notes and recommendations
- **Whiskey recommendations** with price ranges ($, $$, $$$)
- **Purchase system** for individual presentations

### 🎫 **Events**
- **Event creation and management**
- **RSVP system** for society members
- **Event details** and coordination tools

### 👤 **User Management**
- **Authentication** with Devise
- **User profiles** and preferences
- **Society memberships** and applications

## 🚀 Quick Start

### Prerequisites
- Ruby 3.2+
- PostgreSQL 14+
- Node.js 18+
- Docker (optional)

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/wsethbrown/wss.git
   cd wss
   ```

2. **Install dependencies**
   ```bash
   bundle install
   npm install
   ```

3. **Database setup**
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Start the development server**
   ```bash
   bin/dev
   ```

5. **Visit the application**
   ```
   http://localhost:3000
   ```

### Docker Setup

1. **Build and run with Docker Compose**
   ```bash
   docker-compose up --build
   ```

2. **Or use the provided Dockerfile**
   ```bash
   docker build -t whiskey-share-society .
   docker run -p 3000:3000 whiskey-share-society
   ```

## 🛠️ Technology Stack

### **Backend**
- **Rails 7.1+** - Modern Ruby web framework
- **Ruby 3.2+** - Latest Ruby with performance improvements
- **PostgreSQL** - Robust relational database
- **Devise** - Authentication and user management
- **Pundit** - Authorization policies

### **Frontend**
- **Hotwire** - Modern Rails frontend approach
- **Tailwind CSS 3.3+** - Utility-first CSS framework
- **Stimulus** - Lightweight JavaScript framework
- **Turbo** - Fast navigation and form handling

### **Development & Deployment**
- **Docker** - Containerization for consistent environments
- **GitHub Actions** - CI/CD pipeline
- **Kamal** - Modern Rails deployment
- **RuboCop** - Code quality and style enforcement

## 📁 Project Structure

```
wss/
├── app/
│   ├── controllers/     # Rails controllers
│   ├── models/         # ActiveRecord models
│   ├── views/          # ERB templates
│   ├── assets/         # Images and static files
│   └── javascript/     # Stimulus controllers
├── config/             # Rails configuration
├── db/                 # Database migrations and seeds
├── public/             # Static files
└── vendor/             # Third-party dependencies
```

## 🎨 Design Philosophy

### **Modern Aesthetics**
- **Glassmorphism** effects with backdrop blur
- **Gradient backgrounds** and smooth animations
- **Responsive design** that works on all devices
- **Accessible** with proper contrast and keyboard navigation

### **User Experience**
- **Intuitive navigation** with clear visual hierarchy
- **Fast, responsive** interactions with minimal loading times
- **Progressive enhancement** for better accessibility
- **Mobile-first** design approach

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# Database
DATABASE_URL=postgresql://localhost/wss_development

# Rails
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_here

# Devise
DEVISE_SECRET_KEY=your_devise_secret_here
```

### Database Configuration

The application uses PostgreSQL by default. Update `config/database.yml` for your environment:

```yaml
development:
  adapter: postgresql
  database: wss_development
  host: localhost
  username: your_username
  password: your_password
```

## 🚀 Deployment

### Production Setup

1. **Set environment variables**
   ```bash
   export RAILS_ENV=production
   export SECRET_KEY_BASE=$(rails secret)
   ```

2. **Precompile assets**
   ```bash
   rails assets:precompile
   ```

3. **Database setup**
   ```bash
   rails db:migrate
   rails db:seed
   ```

### Docker Deployment

```bash
# Build production image
docker build -f Dockerfile.prod -t wss:production .

# Run with environment variables
docker run -d \
  -p 3000:3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=your_secret \
  wss:production
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Ruby style guidelines with RuboCop
- Write tests for new features
- Update documentation as needed
- Ensure responsive design works on all screen sizes

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Rails team** for the amazing framework
- **Tailwind CSS** for the utility-first approach
- **Hotwire** for modern Rails frontend patterns
- **Whiskey community** for inspiration and feedback

---

**Built with ❤️ for whiskey enthusiasts everywhere**

*Discover. Share. Savor.*
