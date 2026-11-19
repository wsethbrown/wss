namespace :credits do
  # B5 / M1: REPORTS (never grants) how many monthly credits each current
  # quarterly or yearly member would have received under the one-credit-a-month
  # rule since their current subscription began, against what they received.
  # Whether to back-pay is an owner decision; this task changes nothing.
  desc "Report credits owed to quarterly/yearly members under the monthly rule (read-only)"
  task owed: :environment do
    rows = MonthlyCreditJob.owed_report
    if rows.empty?
      puts "No active quarterly or yearly members."
      next
    end

    puts format("%-8s %-10s %-11s %8s %8s %5s", "user", "plan", "since", "expected", "received", "owed")
    rows.each do |r|
      if r[:since]
        puts format("%-8s %-10s %-11s %8d %8d %5d", r[:user_id], r[:plan], r[:since], r[:expected], r[:received], r[:owed])
      else
        puts format("%-8s %-10s %-11s %s", r[:user_id], r[:plan], "unknown", "no granted credit on the ledger; check Stripe")
      end
    end
    total = rows.sum { |r| r[:owed].to_i }
    puts "Total owed: #{total} credit(s) across #{rows.count { |r| r[:owed].to_i.positive? }} member(s). Nothing was granted."
  end
end
