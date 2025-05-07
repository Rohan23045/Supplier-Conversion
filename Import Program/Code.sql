create or replace package xxrp_sup_conv_pkg as
   procedure xxrp_val_proc (
      errbuf       out varchar2,
      retcode      out number,
      p_request_id in number
   );
end xxrp_sup_conv_pkg;
/



create or replace package body xxrp_sup_conv_pkg as

-- Global Variables Declaration
--------------------------------------------------------------------------------------
   gn_user_id      constant number := fnd_profile.value('USER_ID');
   gn_resp_id      constant number := fnd_profile.value('RESP_ID');
   gn_resp_appl_id constant number := fnd_profile.value('RESP_APPL_ID');
   gn_err_cnt      number;
   gn_suc_cnt      number;
   gn_ledger_id    number;-- := FND_PROFILE.VALUE('GL_SET_OF_BKS_ID');
   gn_org_id       number := fnd_profile.value('ORG_ID');



   procedure xxrp_val_proc (
      errbuf       out varchar2,
      retcode      out number,
      p_request_id in number
   ) is

-- Cursor For Fetching The Supplier data 
--------------------------------------------------------------------------------------
      cursor cu_xx_bulk_ap_sup_val_data (
         p_request_id in number
      ) is
      select rowid,
             a.*
        from xxacse.xxrp_supplier_conv_stg a
       where a.request_id = p_request_id
         and a.process_status = 'N';
		
	
	

--------------------------------------------------------------------------------------
-- Declaring Variables For Validation
--------------------------------------------------------------------------------------
      lc_proc_name           varchar2(80) := 'XXRP_VAL_PROC';
      ln_vendor_interface_id number;
      lc_error_flag          varchar2(10);
      lc_error_msg           varchar2(5000);
      ln_vendor_cnt          number;
      ln_term_id             number;
      lc_currency_code       varchar2(10);
      lc_vendor_type         varchar2(50);
      ln_vendor_site_count   number;
      lc_payment_method_code varchar2(240);
      lc_pay_grp_lkp_cd      varchar2(240);
      ln_valid_addr_cnt      number;
      ln_country_chk         number;
      ln_bank_id             number;
      ln_branch_id           number;
      ln_account_id          number;
      ln_vendor_id           number;
      ln_party_id            number;
      ln_org_id              number;
      ln_party_site_id       number;
      ln_vendor_site_id      number;
      ln_location_id         number;
   begin
      lc_error_msg := '';
      for rec in cu_xx_bulk_ap_sup_val_data(p_request_id) loop
		--------------------------------------------------------------------------------------
		-- All Local Variables Sets To NULL
		--------------------------------------------------------------------------------------

         lc_error_flag := null;
         lc_error_msg := null;
         ln_vendor_cnt := null;
         ln_vendor_site_count := null;
         lc_vendor_type := null;
         ln_valid_addr_cnt := null;
         ln_term_id := null;
         lc_currency_code := null;
         ln_country_chk := null;
         ln_bank_id := null;
         ln_branch_id := null;
         ln_account_id := null;
         ln_vendor_id := null;
         ln_party_id := null;
         ln_vendor_site_id := null;
         ln_party_site_id := null;
         ln_term_id := null;
         ln_location_id := null;
         fnd_file.put_line(
            fnd_file.log,
            '--------------------------------------------------------------------------------------'
         );
         fnd_file.put_line(
            fnd_file.log,
            'Vendor Name : ' || rec.vendor_name
         );
         lc_error_msg := '';
	-----------------------------------------------------------------------
	--VALIDATING VENDOR_NAME :
	-----------------------------------------------------------------------
         if rec.vendor_name is not null then
            begin
        -- Check if vendor already exists
               select count(vendor_id)
                 into ln_vendor_cnt
                 from ap_suppliers
                where upper(vendor_name) = upper(rec.vendor_name);

               if ln_vendor_cnt > 0 then
            -- Vendor already exists, raise an error
                  lc_error_flag := 'E';
                  lc_error_msg := lc_error_msg
                                  || ': Duplicate vendor name not allowed: '
                                  || rec.vendor_name;
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
               end if;

        

            exception
               when others then
                  lc_error_flag := 'E';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  lc_error_msg := lc_error_msg
                                  || ':'
                                  || lc_proc_name
                                  || '-'
                                  || 'Exception while processing vendor_name '
                                  || sqlerrm
                                  || '.At Location:'
                                  || dbms_utility.format_error_backtrace;
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
            end;
         end if;
		-----------------------------------------------------------------------
		--VALIDATING VENDOR_SITE_CODE :
		-----------------------------------------------------------------------
         if rec.vendor_site_code is not null then
            begin
               select count(vendor_site_id)
                 into ln_vendor_site_count
                 from ap_supplier_sites_all assa,
                      ap_suppliers ass
                where upper(assa.vendor_site_code) = upper(rec.vendor_site_code)
                  and upper(ass.vendor_name) = upper(rec.vendor_name)
                  and ass.vendor_id = assa.vendor_id;

               if ln_vendor_site_count > 0 then
                  select assa.vendor_site_id,
                         party_site_id
                    into
                     ln_vendor_site_id,
                     ln_party_site_id
                    from ap_supplier_sites_all assa,
                         ap_suppliers ass
                   where upper(assa.vendor_site_code) = upper(rec.vendor_site_code)
                     and upper(ass.vendor_name) = upper(rec.vendor_name)
                     and ass.vendor_id = assa.vendor_id;

                  update xxacse.xxrp_supplier_conv_stg
                     set vendor_site_id = ln_vendor_site_id,
                         party_site_id = ln_party_site_id
                   where upper(vendor_name) = upper(rec.vendor_name)
                     and upper(vendor_site_code) = upper(rec.vendor_site_code);
                  commit;
               end if;
            exception
               when others then
                  lc_error_flag := 'E';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  lc_error_msg := lc_error_msg
                                  || ':'
                                  || lc_proc_name
                                  || '-'
                                  || 'Error while Fetching vendor site id  based on Vendor Site'
                                  || sqlerrm
                                  || '.At Location:'
                                  || dbms_utility.format_error_backtrace;
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
            end;
         end if;
         fnd_file.put_line(
            fnd_file.log,
            'ln_vendor_site_count  : ' || ln_vendor_site_count
         );
		-----------------------------------------------------------------------
		--VALIDATING VENDOR_TYPE :
		-----------------------------------------------------------------------
--		IF rec.vendor_type IS NOT NULL 
--        THEN 
--			BEGIN 
--				SELECT  DISTINCT lookup_code
--                INTO    lc_vendor_type
--                FROM 	fnd_lookup_values
--                WHERE 	1=1
--                  AND   lookup_type   = 'VENDOR TYPE'
--                  AND   UPPER(lookup_code)   = UPPER(rec.vendor_type)
--                  AND   LANGUAGE      	   = ('US') 
--				  AND   start_date_active IS NOT NULL ; 
--
--				IF lc_vendor_type IS NULL THEN
--                 lc_error_flag := 'E';
--                 lc_error_msg :=lc_error_msg ||':'||' vendor_type is not exists in base table';
--                 fnd_file.put_line(fnd_file.log, 'lc_error_flag :' || lc_error_flag);
--                 fnd_file.put_line(fnd_file.log, 'lc_error_msg :' || lc_error_msg);
--				END IF;
--			EXCEPTION
--				WHEN OTHERS THEN
--					lc_error_flag := 'E';
--					fnd_file.put_line(fnd_file.log, 'lc_error_flag :' || lc_error_flag);
--				    lc_error_msg := lc_error_msg ||':'|| lc_proc_name
--												 ||'-'||'Exception while Fetching vendor_type ' 
--											     || SQLERRM
--											     || '.At Location:'
--											     || DBMS_UTILITY.format_error_backtrace;
--					fnd_file.put_line(fnd_file.log, 'lc_error_msg :' || lc_error_msg);
--			END;
--		END IF;
--        fnd_file.put_line(fnd_file.log, 'lc_vendor_type  : '||lc_vendor_type);


    -- VALIDATING VENDOR_TYPE
-----------------------------------------------------------------------
--IF rec.vendor_type IS NOT NULL THEN
--    BEGIN
--        -- Attempt to fetch the vendor type from fnd_lookup_values
--        BEGIN
--            SELECT DISTINCT lookup_code
--            INTO lc_vendor_type
--            FROM fnd_lookup_values
--            WHERE lookup_type = 'VENDOR TYPE'
--              AND UPPER(lookup_code) = UPPER(rec.vendor_type)
--              AND LANGUAGE = 'US'
--              AND start_date_active IS NOT NULL;
--
--        EXCEPTION
--            WHEN NO_DATA_FOUND THEN
--                -- Handle the case where no data is found
--                lc_error_flag := 'E';
--                lc_error_msg := lc_error_msg || ': vendor_type ' || rec.vendor_type || ' does not exist in base table';
--                fnd_file.put_line(fnd_file.log, 'lc_error_flag :' || lc_error_flag);
--                fnd_file.put_line(fnd_file.log, 'lc_error_msg :' || lc_error_msg);
--            WHEN OTHERS THEN
--                -- Handle any other exceptions
--                lc_error_flag := 'E';
--                lc_error_msg := lc_error_msg || ':' || lc_proc_name
--                                                 || ' - Exception while Fetching vendor_type '
--                                                 || SQLERRM
--                                                 || '. At Location: '
--                                                 || DBMS_UTILITY.format_error_backtrace;
--                fnd_file.put_line(fnd_file.log, 'lc_error_flag :' || lc_error_flag);
--                fnd_file.put_line(fnd_file.log, 'lc_error_msg :' || lc_error_msg);
--        END;
--
--    EXCEPTION
--        WHEN OTHERS THEN
--            -- Outer exception handler if needed for the whole block
--            lc_error_flag := 'E';
--            lc_error_msg := lc_error_msg || ':' || lc_proc_name
--                                             || ' - Exception while processing vendor_type: ' 
--                                             || SQLERRM
--                                             || '. At Location: '
--                                             || DBMS_UTILITY.format_error_backtrace;
--            fnd_file.put_line(fnd_file.log, 'lc_error_flag :' || lc_error_flag);
--            fnd_file.put_line(fnd_file.log, 'lc_error_msg :' || lc_error_msg);
--    END;
--END IF;
--
---- Log the final vendor_type value
--fnd_file.put_line(fnd_file.log, 'lc_vendor_type  : ' || lc_vendor_type);

		-----------------------------------------------------------------------
		--VALIDATING Address_Line1 :
		-----------------------------------------------------------------------
         if rec.address_line1 is not null then
            begin
               select count(1)
                 into ln_valid_addr_cnt
                 from (
                  select geography_element4 city
                    from hz_geographies
                   where 1 = 1
                     and upper(geography_element2) = upper(rec.state)
                     and upper(geography_element3) = upper(rec.county)
                     and upper(geography_element4) = upper(rec.city)
                     and country_code = 'US'
                     and geography_type = 'ZIP'
                     and geography_code = substr(
                     rec.zip,
                     1,
                     5
                  )
                  union
                  select identifier_value city
                    from hz_geography_identifiers
                   where 1 = 1
                     and geo_data_provider = 'USER_ENTERED'
                     and geography_type = 'CITY'
                     and identifier_value = upper(rec.city)
               );

               if ln_valid_addr_cnt is null then
                  lc_error_flag := 'E';
                  lc_error_msg := lc_error_msg
                                  || ':'
                                  || 'this address_line1 is should be in right format';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
               end if;
            exception
               when others then
                  lc_error_flag := 'E';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  lc_error_msg := lc_error_msg
                                  || lc_proc_name
                                  || '-'
                                  || 'Exception while Fetching address_line1'
                                  || ln_valid_addr_cnt
                                  || sqlerrm
                                  || '.At Location:'
                                  || dbms_utility.format_error_backtrace;
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
            end;
         end if;
         fnd_file.put_line(
            fnd_file.log,
            'ln_valid_addr_cnt  : ' || ln_valid_addr_cnt
         );
		

        -----------------------------------------------------
		--------VALIDATING COUNTRY
		------------------------------------------------------		
         if rec.country is not null then
            begin
               select count(territory_code)
                 into ln_country_chk
                 from fnd_territories
                where 1 = 1
                  and territory_code = rec.country
                  and rownum = 1;

               if ln_country_chk = 0 then
                  lc_error_flag := 'E';
                  lc_error_msg := lc_error_msg
                                  || ':'
                                  || 'this country is exits in base table';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
               end if;
            exception
               when others then
                  lc_error_flag := 'E';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  lc_error_msg := lc_error_msg
                                  || ':'
                                  || ','
                                  || lc_proc_name
                                  || '-'
                                  || 'Exception while Fetching country'
                                  || sqlerrm
                                  || '.At Location:'
                                  || dbms_utility.format_error_backtrace;
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
            end;
         end if;
         fnd_file.put_line(
            fnd_file.log,
            'ln_country_chk  : ' || ln_country_chk
         );
		-----------------------------------------------------
		
		
		--------VALIDATING TERMS
		------------------------------------------------------
         if rec.terms_name is not null then
            begin
               select term_id
                 into ln_term_id
                 from ap_terms_tl a
                where upper(a.name) = upper(rec.terms_name)
                  and a.language = 'US';

               if ln_term_id is not null then
                  update xxacse.xxrp_supplier_conv_stg
                     set
                     terms_id = ln_term_id
                   where upper(terms_name) = upper(rec.terms_name);
                  commit;
               else
                  lc_error_flag := 'E';
                  lc_error_msg := lc_error_msg
                                  || ':'
                                  || 'this terms not exists in base table';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
               end if;
            exception
               when others then
                  lc_error_flag := 'E';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  lc_error_msg := lc_error_msg
                                  || ','
                                  || lc_proc_name
                                  || '-'
                                  || 'Exception while Fetching vendor terms '
                                  || ln_term_id
                                  || sqlerrm
                                  || '.At Location:'
                                  || dbms_utility.format_error_backtrace;
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
            end;
         end if;
         fnd_file.put_line(
            fnd_file.log,
            'ln_term_id  : ' || ln_term_id
         );
		-----------------------------------------------------
		--------VALIDATING INVOICE_CURRENCY_CODE
		------------------------------------------------------
         if rec.invoice_currency_code is not null then
            begin
               select currency_code
                 into lc_currency_code
                 from fnd_currencies
                where upper(currency_code) = upper(rec.invoice_currency_code);

               if lc_currency_code is null then
                  lc_error_flag := 'E';
                  lc_error_msg := lc_error_msg
                                  || ':'
                                  || 'this invoice_currency_code not exists in base table';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
               else
                  fnd_file.put_line(
                     fnd_file.log,
                     'Invoice currency code validated successfully.'
                  );
               end if;
            exception
               when others then
                  lc_error_flag := 'E';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  lc_error_msg := lc_error_msg
                                  || ','
                                  || lc_proc_name
                                  || '-'
                                  || 'Exception while Fetching invoice_currency_code'
                                  || sqlerrm
                                  || '.At Location:'
                                  || dbms_utility.format_error_backtrace;
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
            end;
         end if;
         fnd_file.put_line(
            fnd_file.log,
            'lc_currency_code  : ' || lc_currency_code
         );
		-----------------------------------------------------
		--------VALIDATING OPERATING UNIT NAME
		------------------------------------------------------
         if rec.operating_unit_name is not null then
            begin
               select organization_id
                 into ln_org_id
                 from hr_operating_units
                where name = rec.operating_unit_name;

               if ln_org_id is null then
                  lc_error_flag := 'E';
                  lc_error_msg := lc_error_msg
                                  || ':'
                                  || 'this operating_unit_name not exists in base table';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
               else
                  update xxacse.xxrp_supplier_conv_stg
                     set
                     org_id = ln_org_id
                   where vendor_name = rec.vendor_name
                     and request_id = rec.request_id;

               end if;
            exception
               when others then
                  lc_error_flag := 'E';
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_flag :' || lc_error_flag
                  );
                  lc_error_msg := lc_error_msg
                                  || ','
                                  || lc_proc_name
                                  || '-'
                                  || 'EXCEPTION  while Fetching operating_unit_name'
                                  || sqlerrm
                                  || '.At Location:'
                                  || dbms_utility.format_error_backtrace;
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
            end;
         end if;
         fnd_file.put_line(
            fnd_file.log,
            'ln_org_id  : ' || ln_org_id
         );
         
         
         if lc_error_flag = 'E' then
            begin
               update xxrp_supplier_conv_stg
                  set process_status = 'E',
                      error_msg = lc_error_msg
                where request_id = p_request_id
                  and rowid = rec.rowid;
               commit;
            exception
               when others then
                  lc_error_msg := lc_error_msg
                                  || 'Error while updating staging table: '
                                  || sqlerrm;
                  fnd_file.put_line(
                     fnd_file.log,
                     'lc_error_msg :' || lc_error_msg
                  );
            end;
         else
        
    DECLARE
   ln_vendor_interface_id   NUMBER; -- To capture Header Interface ID
   ln_site_interface_id     NUMBER; -- To capture Site Interface ID
   ln_contact_interface_id  NUMBER; -- To capture Contact Interface ID
BEGIN
   -- Update staging status FIRST (before interface inserts)
   UPDATE XXRP_SUPPLIER_CONV_STG
      SET process_status = 'V',
          org_id         = ln_org_id,  -- Store derived org_id
          terms_id       = ln_term_id  -- Store derived terms_id
    WHERE ROWID = rec.ROWID;

   -- Insert into AP_SUPPLIERS_INT (Supplier Header)
   INSERT INTO AP_SUPPLIERS_INT (
      VENDOR_INTERFACE_ID,
      LAST_UPDATE_DATE,
      LAST_UPDATED_BY,
      VENDOR_NAME,
      CREATION_DATE,
      CREATED_BY,
      VENDOR_TYPE_LOOKUP_CODE,
      TERMS_ID,
      TERMS_NAME,
      INVOICE_CURRENCY_CODE,
      PAYMENT_CURRENCY_CODE,
      PAYMENT_METHOD_LOOKUP_CODE,
      ENABLED_FLAG,
      REQUEST_ID,
      STATUS,
      EMAIL_ADDRESS,
      PARTY_ID
   )
   VALUES (
      AP_SUPPLIERS_INT_S.NEXTVAL, -- VENDOR_INTERFACE_ID (Mandatory)
      SYSDATE,                    -- LAST_UPDATE_DATE
      gn_user_id,                 -- LAST_UPDATED_BY
      rec.vendor_name,            -- VENDOR_NAME (Mandatory)
      SYSDATE,                    -- CREATION_DATE
      gn_user_id,                 -- CREATED_BY
      rec.vendor_type,            -- VENDOR_TYPE_LOOKUP_CODE
      ln_term_id,                 -- TERMS_ID (Derived)
      rec.terms_name,             -- TERMS_NAME
      rec.invoice_currency_code,  -- INVOICE_CURRENCY_CODE
      rec.payment_currency_code,  -- PAYMENT_CURRENCY_CODE
      rec.payment_method,         -- PAYMENT_METHOD_LOOKUP_CODE
      'Y',                        -- ENABLED_FLAG (Default to active)
      rec.request_id,             -- REQUEST_ID
      'NEW',                      -- STATUS (Required for import)
      rec.email_address,          -- EMAIL_ADDRESS
      rec.party_id                -- PARTY_ID (If available from staging)
   )
   RETURNING VENDOR_INTERFACE_ID INTO ln_vendor_interface_id;

   -- Insert into AP_SUPPLIER_SITES_INT (Supplier Site)
   INSERT INTO AP_SUPPLIER_SITES_INT (
      VENDOR_INTERFACE_ID,
      LAST_UPDATE_DATE,
      LAST_UPDATED_BY,
      VENDOR_ID,
      VENDOR_SITE_CODE,
      CREATION_DATE,
      CREATED_BY,
      PURCHASING_SITE_FLAG,
      PAY_SITE_FLAG,
      ADDRESS_LINE1,
      ADDRESS_LINE2,
      ADDRESS_LINE3,
      CITY,
      STATE,
      ZIP,
      PROVINCE,
      COUNTRY,
      AREA_CODE,
      PHONE,
      PAYMENT_METHOD_LOOKUP_CODE,
      TERMS_ID,
      TERMS_NAME,
      INVOICE_CURRENCY_CODE,
      PAYMENT_CURRENCY_CODE,
      REQUEST_ID,
      ORG_ID,
      OPERATING_UNIT_NAME,
      COUNTY,
      LANGUAGE,
      EMAIL_ADDRESS,
      PRIMARY_PAY_SITE_FLAG,
      STATUS,
      VENDOR_SITE_INTERFACE_ID,
      PARTY_SITE_ID,
      PARTY_ID,
      LOCATION_ID
   )
   VALUES (
      ln_vendor_interface_id,     -- VENDOR_INTERFACE_ID (Link to supplier)
      SYSDATE,                    -- LAST_UPDATE_DATE
      gn_user_id,                 -- LAST_UPDATED_BY
      rec.vendor_id,              -- VENDOR_ID (If available from staging)
      rec.vendor_site_code,       -- VENDOR_SITE_CODE (Mandatory)
      SYSDATE,                    -- CREATION_DATE
      gn_user_id,                 -- CREATED_BY
      'Y',                        -- PURCHASING_SITE_FLAG (Default)
      'Y',                        -- PAY_SITE_FLAG (Default)
      rec.address_line1,          -- ADDRESS_LINE1
      rec.address_line2,          -- ADDRESS_LINE2
      rec.address_line3,          -- ADDRESS_LINE3
      rec.city,                   -- CITY
      rec.state,                  -- STATE
      rec.zip,                    -- ZIP
      rec.province,               -- PROVINCE
      rec.country,                -- COUNTRY
      rec.area_code,              -- AREA_CODE
      rec.phone,                  -- PHONE
      rec.payment_method,         -- PAYMENT_METHOD_LOOKUP_CODE
      ln_term_id,                 -- TERMS_ID (Derived)
      rec.terms_name,             -- TERMS_NAME
      rec.invoice_currency_code,  -- INVOICE_CURRENCY_CODE
      rec.payment_currency_code,  -- PAYMENT_CURRENCY_CODE
      rec.request_id,             -- REQUEST_ID
      ln_org_id,                  -- ORG_ID (Derived)
      rec.operating_unit_name,    -- OPERATING_UNIT_NAME
      rec.county,                 -- COUNTY
       fnd_global.nls_language,                       -- LANGUAGE (Default)
      rec.email_address,          -- EMAIL_ADDRESS
      'Y',                        -- PRIMARY_PAY_SITE_FLAG (Default)
      'NEW',                      -- STATUS (Required for import)
      AP_SUPPLIER_SITES_INT_S.NEXTVAL, -- VENDOR_SITE_INTERFACE_ID (Mandatory)
      rec.party_site_id,          
      rec.party_id,               
      rec.location_id             
   )
   RETURNING VENDOR_SITE_INTERFACE_ID INTO ln_site_interface_id;

   -- Insert into AP_SUP_SITE_CONTACT_INT (Supplier Contact) if contact data exists
   IF rec.contact_first_name IS NOT NULL OR rec.contact_last_name IS NOT NULL THEN
      INSERT INTO AP_SUP_SITE_CONTACT_INT (
         LAST_UPDATE_DATE,
         LAST_UPDATED_BY,
         VENDOR_SITE_ID,
         VENDOR_SITE_CODE,
         ORG_ID,
         OPERATING_UNIT_NAME,
         CREATION_DATE,
         CREATED_BY,
         FIRST_NAME,
         LAST_NAME,
         AREA_CODE,
         PHONE,
         REQUEST_ID,
         STATUS,
         EMAIL_ADDRESS,
         VENDOR_INTERFACE_ID,
         VENDOR_ID,
         VENDOR_CONTACT_INTERFACE_ID,
         PARTY_SITE_ID,
         PARTY_ID
      )
      VALUES (
         SYSDATE,                    -- LAST_UPDATE_DATE
         gn_user_id,                 -- LAST_UPDATED_BY
         rec.vendor_site_id,         -- VENDOR_SITE_ID (If available from staging)
         rec.vendor_site_code,       -- VENDOR_SITE_CODE (Link to site)
         ln_org_id,                  -- ORG_ID (Derived)
         rec.operating_unit_name,    -- OPERATING_UNIT_NAME
         SYSDATE,                    -- CREATION_DATE
         gn_user_id,                 -- CREATED_BY
         rec.contact_first_name,     -- FIRST_NAME
         rec.contact_last_name,      -- LAST_NAME
         rec.area_code,              -- AREA_CODE
         rec.phone,                  -- PHONE
         rec.request_id,             -- REQUEST_ID
         'NEW',                      -- STATUS (Required for import)
         rec.email_address,          -- EMAIL_ADDRESS
         ln_vendor_interface_id,     -- VENDOR_INTERFACE_ID (Link to supplier)
         rec.vendor_id,              -- VENDOR_ID (If available from staging)
         AP_SUP_SITE_CONTACT_INT_S.NEXTVAL, -- VENDOR_CONTACT_INTERFACE_ID (Mandatory)
         rec.party_site_id,          -- PARTY_SITE_ID (If available from staging)
         rec.party_id                -- PARTY_ID (If available from staging)
      )
      RETURNING VENDOR_CONTACT_INTERFACE_ID INTO ln_contact_interface_id;

    ELSE
        ln_contact_interface_id := NULL; -- To Ensure variable is null if no contact inserted
        fnd_file.put_line(fnd_file.log, 'No contact details found for Vendor ' || rec.vendor_name || ' Site ' || rec.vendor_site_code || '. Skipping contact insert.');
            
        END IF;

        -- Single Commit after all inserts for this record are successful
               commit;
               fnd_file.put_line(
                  fnd_file.log,
                  'Record for Vendor '
                  || rec.vendor_name
                  || ' Site '
                  || rec.vendor_site_code
                  || ' inserted into interface tables. VendorIntID: '
                  || ln_vendor_interface_id
                  || ', SiteIntID: '
                  || ln_site_interface_id
               );

            exception
               when others then
                  rollback; -- Rollback interface inserts if any part fails for this record
                  lc_error_flag := 'E';
                  lc_error_msg := lc_error_msg
                                  || ': Error inserting into Interface tables: '
                                  || substr(
                     sqlerrm,
                     1,
                     1500
                  );
                  fnd_file.put_line(
                     fnd_file.log,
                     'ERROR inserting interface data for Vendor '
                     || rec.vendor_name
                     || ': '
                     || lc_error_msg
                  );
            -- Update staging table with error AFTER rollback
                  update xxrp_supplier_conv_stg
                     set process_status = 'E',
                         error_msg = substr(
                            lc_error_msg,
                            1,
                            4000
                         )
                   where rowid = rec.rowid;
                  commit; -- Commit the error status update
            end; 

         end if; -- End of IF lc_error_flag = 'E' check

      end loop; -- End of main cursor loop



   exception
      when others then
         errbuf := sqlerrm;
         retcode := 1;
         lc_error_msg := lc_error_msg
                         || 'Exception in this  XXRP_VAL_PROC:'
                         || retcode
                         || '-'
                         || errbuf;
         fnd_file.put_line(
            fnd_file.log,
            'lc_error_msg :' || lc_error_msg
         );
   end xxrp_val_proc;

end xxrp_sup_conv_pkg;
