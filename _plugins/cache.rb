require 'json'

module Cache
  class Generator < Jekyll::Generator

    def generate_cache(site)
      cache = {}
      for collection in ["legislators", "districts", "committees", "bill_events", "issues" ,"bills"] do
        item_by_id = {}
        for item in site.collections[collection].docs do
          id = item['aom_id']
          item_by_id[id] = item
          item.data['json'] = item.data.to_json
        end
        cache["#{collection}_by_id"] = item_by_id
      end
      site.data["cache"] = cache
    end

    def generate_legislator_committees(site)
      cache = site.data["cache"]
      for legislator in site.collections["legislators"].docs do
        legislator.data["committees"] = []
      end
      legislators = cache["legislators_by_id"]
      for committee in site.collections["committees"].docs do
        title = committee["title"]
        for chamber in  ["house","senate"] do
          if [chamber, "joint"].include? committee["chamber"] then
            chair = legislators[committee["#{chamber}_chair"]]
            if (chair != nil) then
              chair.data["committees"].push({"role" => "Chair", "title" => title, "priority" => 1})
            end
            vice_chair = legislators[committee["#{chamber}_vice_chair"]]
            if (chair != nil) then
              vice_chair.data["committees"].push({"role" => "Vice-chair", "title" => title, "priority" => 2})
            end
            for member_id in committee["#{chamber}_members"] do
              member = legislators[member_id]
              member.data["committees"].push({"role" => "Member", "title" => title, "priority" => 3})
            end
          end
        end
      end
    end

    def generate_legislator_votes(site)
      cache = site.data["cache"]
      for legislator in site.collections["legislators"].docs do
        legislator.data["votes"] = []
      end
      legislators = cache["legislators_by_id"]
      for bill_event in site.collections["bill_events"].docs do
        votes = bill_event.data["votes"]
        if (votes == nil) then
          next
        end
        votes.each do |vote_object|
          leg = legislators[vote_object['legislator']]
          vote = vote_object['vote']
          if (leg == nil) then
            next  # Ignore legislators that are not in our DB
          end
          if bill_event.data["progressive_vote"] then
            is_progressive_vote = vote
          else
            is_progressive_vote = (vote.is_a? String) ? vote : !vote
          end
          vote_description = bill_event.data["vote_descriptions"][vote]
          leg.data["votes"].push({
            "is_progressive" => is_progressive_vote,
            "description" => vote_description,
            "date" => bill_event.data["date"],
            "priority" => bill_event.data["prority"],
          })
        end
      end
    end

    def generate_legislator_cosponsored_bills(site)
      cache = site.data["cache"]
      for legislator in site.collections["legislators"].docs do
        legislator.data["cosponsored_bills"] = []
      end
      legislators = cache["legislators_by_id"]
      for bill in site.collections["bills"].docs do
        co_sponsors = bill.data["co_sponsors"]
        if (co_sponsors == nil) then
          next  # Bill has no co-sponsors, we ignore it
        end
        for leg_id in co_sponsors do
          leg = legislators[leg_id]
          leg.data["cosponsored_bills"].push(bill['aom_id'])
        end
      end
    end

    def generate_legislator_pledge(site)
      cache = site.data["cache"]
      for legislator in site.collections["legislators"].docs do
        legislator.data["pledge"] = false
      end
      legislators = cache["legislators_by_id"]
      signatories = site.data["pledge_signatories"]["house"] + site.data["pledge_signatories"]["senate"]
      for leg_id in signatories
        leg = legislators[leg_id]
        leg.data["pledge"] = true
      end
    end

    def generate_issue_bills(site)
      cache = site.data["cache"]
      for issue in site.collections["issues"].docs do
        issue.data["bills"] = []
      end
      issues = cache["issues_by_id"]
      for bill in site.collections["bills"].docs do
        issue_id = bill.data["issue"]
        issue = issues[issue_id]
        if issue != nil
          issue.data["bills"].push(bill['aom_id'])
        end
      end
    end

    def generate(site)
      generate_cache(site)
      generate_legislator_committees(site)
      generate_legislator_votes(site)
      generate_legislator_cosponsored_bills(site)
      generate_issue_bills(site)
      generate_legislator_pledge(site)
    end
  end
end
