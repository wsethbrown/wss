#!/usr/bin/env ruby

# Watch for new emails and display them
mail_dir = "/Users/sethbrown/Documents/wss/tmp/mail"

puts "🔍 Watching for emails in #{mail_dir}"
puts "Submit the magic link form, then check here for the email content..."
puts "=" * 80

# Function to extract magic link from email content
def extract_magic_link(content)
  if content.match(/magic_links\/([a-zA-Z0-9_-]+)/)
    full_match = content.match(/https:\/\/dev\.whiskeysharesociety\.com:3000\/magic_links\/([a-zA-Z0-9_-]+)/)
    return full_match[0] if full_match
  end
  nil
end

# Function to display email nicely
def display_email(file_path)
  content = File.read(file_path)
  
  puts
  puts "📧 NEW EMAIL RECEIVED!"
  puts "=" * 50
  puts "File: #{File.basename(file_path)}"
  puts "Time: #{File.mtime(file_path)}"
  puts
  
  # Extract and highlight the magic link
  magic_link = extract_magic_link(content)
  
  if magic_link
    puts "🔗 MAGIC LINK FOUND:"
    puts magic_link
    puts
    puts "To test: Copy the above URL and paste it into your browser"
    puts
  end
  
  puts "📄 Full Email Content:"
  puts "-" * 30
  puts content
  puts "-" * 30
  puts
end

# Check for existing emails first
existing_files = Dir.glob("#{mail_dir}/*").sort_by { |f| File.mtime(f) }
if existing_files.any?
  puts "Found #{existing_files.length} existing email(s):"
  existing_files.each { |file| display_email(file) }
else
  puts "No existing emails found."
end

puts
puts "Watching for new emails... (Press Ctrl+C to stop)"

# Watch for new files
last_count = existing_files.length
loop do
  current_files = Dir.glob("#{mail_dir}/*").sort_by { |f| File.mtime(f) }
  
  if current_files.length > last_count
    # New email(s) arrived
    new_files = current_files[last_count..-1]
    new_files.each { |file| display_email(file) }
    last_count = current_files.length
  end
  
  sleep 1
end