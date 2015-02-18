module FastlaneCore
  class DeveloperCenter
    # Returns a array of hashes, that contains information about the iOS certificate
    # @example
      # [{"certRequestId"=>"B23Q2P396B",
      # "name"=>"SunApps GmbH",
      # "statusString"=>"Issued",
      # "expirationDate"=>"2015-11-25T22:45:50Z",
      # "expirationDateString"=>"Nov 25, 2015",
      # "ownerType"=>"team",
      # "ownerName"=>"SunApps GmbH",
      # "ownerId"=>"....",
      # "canDownload"=>true,
      # "canRevoke"=>true,
      # "certificateId"=>"....",
      # "certificateStatusCode"=>0,
      # "certRequestStatusCode"=>4,
      # "certificateTypeDisplayId"=>"...",
      # "serialNum"=>"....",
      # "typeString"=>"iOS Distribution"},
      # {another sertificate...}]
    def code_signing_certificates(type, cert_date)
      certs_url = "https://developer.apple.com/account/ios/certificate/certificateList.action?type="
      certs_url << (type == DEVELOPMENT ? 'development' : 'distribution')
      visit certs_url

      certificateDataURL = wait_for_variable('certificateDataURL')
      certificateRequestTypes = wait_for_variable('certificateRequestTypes')
      certificateStatuses = wait_for_variable('certificateStatuses')

      url = [certificateDataURL, certificateRequestTypes, certificateStatuses].join('')

      # https://developer.apple.com/services-account/.../account/ios/certificate/listCertRequests.action?content-type=application/x-www-form-urlencoded&accept=application/json&requestId=...&userLocale=en_US&teamId=...&types=...&status=4&certificateStatus=0&type=distribution

      certs = post_ajax(url)['certRequests']

      ret_certs = []
      certificate_name = ENV['SIGH_CERTIFICATE']

      # The other profiles are push profiles
      certificate_type = type == DEVELOPMENT ? 'iOS Development' : 'iOS Distribution'
      
      # New profiles first
      certs.sort! do |a, b|
        Time.parse(b['expirationDate']) <=> Time.parse(a['expirationDate'])
      end

      certs.each do |current_cert|
        next unless current_cert['typeString'] == certificate_type

        if cert_date || certificate_name
          if current_cert['expirationDateString'] == cert_date
            Helper.log.info "Certificate ID '#{current_cert['certificateId']}' with expiry date '#{current_cert['expirationDateString']}' located"
            ret_certs << current_cert
          end
          if current_cert['name'] == certificate_name
            Helper.log.info "Certificate ID '#{current_cert['certificateId']}' with name '#{certificate_name}' located"
            ret_certs << current_cert
          end
        else
          ret_certs << current_cert
        end
      end

      return ret_certs unless ret_certs.empty?

      predicates = []
      predicates << "name: #{certificate_name}" if certificate_name
      predicates << "expiry date: #{cert_date}" if cert_date

      predicates_str = " with #{predicates.join(' or ')}"

      raise "Could not find a Certificate#{predicates_str}. Please open #{current_url} and make sure you have a signing profile created.".red
    end
  end
end