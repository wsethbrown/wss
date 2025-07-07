# 🥃 Whiskey Share Society - Project Knowledge

## 📋 **Project Overview**
Whiskey Share Society is a platform where users can:
- Join exclusive whiskey clubs
- RSVP to whiskey tasting events
- Purchase ready-made whiskey presentations (slides, scripts, outlines, whiskey recommendations)
- Host their own whiskey nights using the provided materials

## 🎨 **Design Philosophy & UI Preferences**

### **Design Inspiration**
- **Primary inspiration**: https://cluely.com
- **Style**: Bold, modern, minimal, clean
- **Color scheme**: Blues, whites, blacks with subtle gradients

### **UI Component Preferences**
- **Search bars**: Always oversized when adding search functionality
- **Login options**: Magic link, Google, and Apple only (explicitly no GitHub)
- **Forms**: Custom, fully styled (no default browser styling)
- **Interactions**: Seamless, modern, polished experiences

### **Layout Patterns**
- **Hero sections**: Full-width, bold typography, no logos, flush with navbar
- **Interactive sections**: Sticky columns with scrollable content
- **Typography**: Large, bold text with emojis for visual hierarchy

## 🏗️ **Technical Architecture**

### **Stack**
- **Framework**: Rails (full-stack, Hotwire, Tailwind)
- **Styling**: Tailwind CSS
- **Interactions**: Hotwire + custom JavaScript
- **Database**: PostgreSQL
- **Deployment**: Docker-based (Dockerfile present)

### **Key Implementation Patterns**
- **Scroll proxy**: Custom JavaScript for seamless section scrolling
- **Snap scrolling**: Native CSS snap for precise positioning
- **Sticky layouts**: Left column sticky, right column scrollable
- **Modern interactions**: Smooth animations, no jittery behavior

## 🎯 **Current Features**

### **Home Page**
- **Hero section**: "Discover. Share. Savor. Whiskey, Together."
- **Subheadline**: "Ready-made whiskey experiences, in a single click. Join exclusive clubs, RSVP to tastings, and share your favorites."
- **How it Works section**: 3-step interactive experience with sticky left column and snap-scrolling right column

### **User Experience**
- **Seamless scrolling**: Works from anywhere in interactive sections
- **Visual feedback**: No focus borders or disruptive highlights
- **Responsive design**: Mobile-first approach with Tailwind

## 🏛️ **Societies Feature**

### **Core Concept**
Societies are whiskey clubs that help coordinate Events, allowing members to see upcoming events and RSVP. They serve as the primary organizational unit for whiskey enthusiasts.

### **Society Types**
- **Public Societies**: Any user can join directly
- **Private Societies**: Users must apply and be approved by admins/officers

### **User Roles & Permissions**

#### **Admin**
- **Creator**: User who creates a Society becomes an Admin
- **Officer Management**: Can appoint and remove Officers
- **Member Management**: Can approve applications and remove users
- **Full Control**: Complete administrative access to the Society

#### **Officer**
- **Appointed by**: Admin
- **Member Management**: Can approve applications and remove users
- **Event Coordination**: Help manage Society events
- **Cannot**: Remove other Officers or the Admin

#### **Member**
- **Public Societies**: Can join directly
- **Private Societies**: Must apply and be approved
- **Event Access**: Can view and RSVP to Society events
- **Forum Access**: Can participate in Society forums

### **Society Features**
- **Events**: Primary purpose - coordinate whiskey tasting events
- **Forums**: Discussion spaces for members
- **Member Management**: Application/approval system for private societies
- **Role Management**: Admin can appoint Officers

### **Business Logic**
- **Creation**: Any user can create a Society and becomes Admin
- **Joining Public**: Direct join, no approval needed
- **Joining Private**: Application → Admin/Officer approval → Membership
- **Event Coordination**: Core purpose - members see upcoming events and RSVP
- **Hierarchy**: Admin > Officer > Member

## 🚀 **Development Guidelines**

### **Code Quality**
- **No placeholders**: Everything must be production-ready
- **Performance first**: Optimized queries, no N+1 issues
- **Modern Rails**: Follow current best practices
- **Clean interactions**: Smooth, polished user experience

### **User-Centric Approach**
- **Polish over features**: Quality of experience trumps quantity of features
- **Modern expectations**: Users expect seamless, app-like experiences
- **Accessibility**: Clean, readable, navigable interfaces

## 📝 **Implementation Notes**

### **Recent Achievements**
- **Scroll proxy system**: Smooth section scrolling that works from any cursor position
- **Native snap integration**: Leverages browser's built-in snap scrolling for reliability
- **Visual polish**: Eliminated focus borders and jittery behavior

### **Key Learnings**
- **Simple is better**: Native browser features often outperform custom implementations
- **User experience first**: Every interaction should feel natural and polished
- **Performance matters**: Smooth scrolling and responsive interactions are non-negotiable

---

*Last updated: Current session - Societies feature requirements documented*