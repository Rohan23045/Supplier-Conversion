CREATE OR REPLACE PACKAGE XX_RP_SUP_API_PKG
IS
  PROCEDURE MAIN(
    ERRBUFF      OUT VARCHAR2,
    RETCODE      OUT NUMBER,
    P_REQUEST_ID IN NUMBER
  );
END XX_RP_SUP_API_PKG;
/

CREATE OR REPLACE PACKAGE BODY XX_RP_SUP_API_PKG
AS
  PROCEDURE MAIN(
    ERRBUFF      OUT VARCHAR2,
    RETCODE      OUT NUMBER,
    P_REQUEST_ID IN NUMBER
  ) IS
    CURSOR my_cur IS
      SELECT *
      FROM XXRP_SUPPLIER_CONV_STG
      WHERE PROCESS_STATUS = 'N'
        AND REQUEST_ID = P_REQUEST_ID;

    l_err_msg           VARCHAR2(360);
    l_err_flg           VARCHAR2(1);
    l_vendor_id         NUMBER;
    l_party_id          NUMBER;
    l_vendor_site_id    NUMBER;
    l_party_site_id     NUMBER;
    l_org_id            NUMBER;
    l_payment_curr      VARCHAR2(10);
    l_invoice_curr      VARCHAR2(10);
    l_term_id           NUMBER;
    l_payment_method    VARCHAR2(30);
    l_country_code      VARCHAR2(20);
    l_site_cnt          NUMBER;
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2000);
    l_api_return_status VARCHAR2(10);
    l_msg               VARCHAR2(2000);
    l_location_id       NUMBER;
    l_vendor_contact_id NUMBER;
    l_rel_party_id      NUMBER;
    l_rel_id            NUMBER;
    l_org_contact_id    NUMBER;
    ln_vendor_cnt       NUMBER;
    ln_valid_addr_cnt   NUMBER;
    ln_country_chk      NUMBER;
    l_supplier_rec      ap_vendor_pub_pkg.r_vendor_rec_type;
    l_supplier_site_rec ap_vendor_pub_pkg.r_vendor_site_rec_type;
    l_contact_rec       ap_vendor_pub_pkg.r_vendor_contact_rec_type;
    l_ext_payee_rec     IBY_DISBURSEMENT_SETUP_PUB.EXTERNAL_PAYEE_REC_TYPE;
    l_ext_payee_tab     IBY_DISBURSEMENT_SETUP_PUB.EXTERNAL_PAYEE_TAB_TYPE;
    l_ext_payee_id_tab  IBY_DISBURSEMENT_SETUP_PUB.EXT_PAYEE_ID_TAB_TYPE;
    l_ext_payee_status_tab IBY_DISBURSEMENT_SETUP_PUB.EXT_PAYEE_CREATE_TAB_TYPE; -- Corrected type

  BEGIN
    FOR rec IN my_cur LOOP
      -- Reset variables for each record
      l_err_msg           := NULL;
      l_err_flg           := NULL;
      l_vendor_id         := NULL;
      l_party_id          := NULL;
      l_vendor_site_id    := NULL;
      l_party_site_id     := NULL;
      l_org_id            := NULL;
      l_payment_curr      := NULL;
      l_invoice_curr      := NULL;
      l_term_id           := NULL;
      l_payment_method    := NULL;
      l_country_code      := NULL;
      l_site_cnt          := NULL;
      l_msg_count         := NULL;
      l_msg_data          := NULL;
      l_api_return_status := NULL;
      l_msg               := NULL;
      l_location_id       := NULL;
      l_vendor_contact_id := NULL;
      l_rel_party_id      := NULL;
      l_rel_id            := NULL;
      l_org_contact_id    := NULL;
      ln_vendor_cnt       := 0;
      ln_valid_addr_cnt   := 0;
      ln_country_chk      := 0;

      DBMS_OUTPUT.put_line('Processing: ' || rec.VENDOR_NAME);

      -- Validate Vendor Name
      BEGIN
        IF rec.VENDOR_NAME IS NULL THEN
          l_err_flg := 'E';
          l_err_msg := 'Vendor Name cannot be null.';
          GOTO error_handler;
        END IF;

        SELECT COUNT(vendor_id)
        INTO ln_vendor_cnt
        FROM ap_suppliers
        WHERE UPPER(vendor_name) = UPPER(rec.VENDOR_NAME);

        IF ln_vendor_cnt > 0 THEN
          l_err_flg := 'E';
          l_err_msg := 'Duplicate vendor name not allowed: ' || rec.VENDOR_NAME;
          GOTO error_handler;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_err_flg := 'E';
          l_err_msg := 'Exception validating vendor name: ' || SQLERRM;
          GOTO error_handler;
      END;

      -- Validate Operating Unit
      BEGIN
        IF rec.OPERATING_UNIT_NAME IS NULL THEN
          l_err_flg := 'E';
          l_err_msg := 'Operating Unit cannot be null.';
          GOTO error_handler;
        END IF;

        SELECT ORGANIZATION_ID
        INTO l_org_id
        FROM HR_OPERATING_UNITS
        WHERE NAME = rec.OPERATING_UNIT_NAME;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_err_flg := 'E';
          l_err_msg := 'Invalid Operating Unit: ' || rec.OPERATING_UNIT_NAME;
          GOTO error_handler;
        WHEN OTHERS THEN
          l_err_flg := 'E';
          l_err_msg := 'Exception validating Operating Unit: ' || SQLERRM;
          GOTO error_handler;
      END;

      -- Validate Payment Currency Code
      BEGIN
        IF rec.PAYMENT_CURRENCY_CODE IS NOT NULL THEN
          SELECT CURRENCY_CODE
          INTO l_payment_curr
          FROM fnd_currencies_vl
          WHERE TRUNC(NVL(END_DATE_ACTIVE, SYSDATE + 1)) > TRUNC(SYSDATE)
            AND UPPER(CURRENCY_CODE) = UPPER(rec.PAYMENT_CURRENCY_CODE);
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_err_flg := 'E';
          l_err_msg := 'Invalid Payment Currency: ' || rec.PAYMENT_CURRENCY_CODE;
          GOTO error_handler;
        WHEN OTHERS THEN
          l_err_flg := 'E';
          l_err_msg := 'Exception validating Payment Currency: ' || SQLERRM;
          GOTO error_handler;
      END;

      -- Validate Invoice Currency Code
      BEGIN
        IF rec.INVOICE_CURRENCY_CODE IS NOT NULL THEN
          SELECT CURRENCY_CODE
          INTO l_invoice_curr
          FROM fnd_currencies_vl
          WHERE TRUNC(NVL(END_DATE_ACTIVE, SYSDATE + 1)) > TRUNC(SYSDATE)
            AND UPPER(CURRENCY_CODE) = UPPER(rec.INVOICE_CURRENCY_CODE);
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_err_flg := 'E';
          l_err_msg := 'Invalid Invoice Currency: ' || rec.INVOICE_CURRENCY_CODE;
          GOTO error_handler;
        WHEN OTHERS THEN
          l_err_flg := 'E';
          l_err_msg := 'Exception validating Invoice Currency: ' || SQLERRM;
          GOTO error_handler;
      END;

      -- Validate Terms Name
      BEGIN
        IF rec.TERMS_NAME IS NOT NULL THEN
          SELECT TERM_ID
          INTO l_term_id
          FROM ap_terms
          WHERE TRUNC(NVL(END_DATE_ACTIVE, SYSDATE + 1)) > TRUNC(SYSDATE)
            AND NAME = rec.TERMS_NAME;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_err_flg := 'E';
          l_err_msg := 'Invalid Terms Name: ' || rec.TERMS_NAME;
          GOTO error_handler;
        WHEN OTHERS THEN
          l_err_flg := 'E';
          l_err_msg := 'Exception validating Terms: ' || SQLERRM;
          GOTO error_handler;
      END;

      -- Validate Vendor Site Code
      BEGIN
        IF rec.VENDOR_SITE_CODE IS NULL THEN
          l_err_flg := 'E';
          l_err_msg := 'Vendor Site Code cannot be null.';
          GOTO error_handler;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_err_flg := 'E';
          l_err_msg := 'Exception validating site code: ' || SQLERRM;
          GOTO error_handler;
      END;

      -- Validate Payment Method
      BEGIN
        IF rec.PAYMENT_METHOD IS NOT NULL THEN
          SELECT PAYMENT_METHOD_CODE
          INTO l_payment_method
          FROM iby_payment_methods_tl
          WHERE UPPER(PAYMENT_METHOD_CODE) = UPPER(rec.PAYMENT_METHOD)
            AND LANGUAGE = USERENV('LANG');
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_err_flg := 'E';
          l_err_msg := 'Invalid Payment Method: ' || rec.PAYMENT_METHOD;
          GOTO error_handler;
        WHEN OTHERS THEN
          l_err_flg := 'E';
          l_err_msg := 'Exception validating Payment Method: ' || SQLERRM;
          GOTO error_handler;
      END;



      -- Validate Country
      BEGIN
        IF rec.COUNTRY IS NOT NULL THEN
          SELECT COUNT(territory_code)
          INTO ln_country_chk
          FROM fnd_territories
          WHERE territory_code = UPPER(rec.COUNTRY);

          IF ln_country_chk = 0 THEN
            l_err_flg := 'E';
            l_err_msg := 'Invalid Country Code: ' || rec.COUNTRY;
            GOTO error_handler;
          END IF;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_err_flg := 'E';
          l_err_msg := 'Exception validating country: ' || SQLERRM;
          GOTO error_handler;
      END;

      -- Create Supplier, Site, and Contact
      IF l_err_flg IS NULL THEN
        DECLARE
          ln_vendor_interface_id   NUMBER := AP_SUPPLIERS_INT_S.NEXTVAL;
          ln_site_interface_id     NUMBER := AP_SUPPLIER_SITES_INT_S.NEXTVAL;
          ln_contact_interface_id  NUMBER := AP_SUP_SITE_CONTACT_INT_S.NEXTVAL;
        BEGIN
          -- Supplier Creation
          BEGIN
            l_supplier_rec.VENDOR_NAME := rec.VENDOR_NAME;
            l_supplier_rec.VENDOR_INTERFACE_ID := ln_vendor_interface_id;
            l_supplier_rec.VENDOR_TYPE_LOOKUP_CODE := rec.VENDOR_TYPE;
            l_supplier_rec.TERMS_ID := l_term_id;
            l_supplier_rec.INVOICE_CURRENCY_CODE := rec.INVOICE_CURRENCY_CODE;
            l_supplier_rec.PAYMENT_CURRENCY_CODE := rec.PAYMENT_CURRENCY_CODE;
            l_supplier_rec.ENABLED_FLAG := 'Y';
            l_supplier_rec.PARTY_ID := rec.PARTY_ID;

            ap_vendor_pub_pkg.create_vendor(
              p_api_version        => 1.0,
              p_init_msg_list      => fnd_api.g_false,
              p_commit             => fnd_api.g_false,
              p_validation_level   => fnd_api.g_valid_level_full,
              x_return_status      => l_api_return_status,
              x_msg_count          => l_msg_count,
              x_msg_data           => l_msg_data,
              p_vendor_rec         => l_supplier_rec,
              x_vendor_id          => l_vendor_id,
              x_party_id           => l_party_id
            );

            IF l_api_return_status != fnd_api.g_ret_sts_success THEN
              l_err_flg := 'E';
              l_err_msg := 'Error creating supplier: ' || FND_MSG_PUB.get(p_msg_index => 1, p_encoded => FND_API.G_FALSE);
              GOTO error_handler;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              l_err_flg := 'E';
              l_err_msg := 'Exception in supplier creation: ' || SQLERRM;
              GOTO error_handler;
          END;

          -- Site Creation
          BEGIN
            l_supplier_site_rec.VENDOR_ID := l_vendor_id;
            l_supplier_site_rec.VENDOR_SITE_CODE := rec.VENDOR_SITE_CODE;
            l_supplier_site_rec.VENDOR_SITE_INTERFACE_ID := ln_site_interface_id;
            l_supplier_site_rec.ADDRESS_LINE1 := rec.ADDRESS_LINE1;
            l_supplier_site_rec.ADDRESS_LINE2 := rec.ADDRESS_LINE2;
            l_supplier_site_rec.ADDRESS_LINE3 := rec.ADDRESS_LINE3;
            l_supplier_site_rec.CITY := rec.CITY;
            l_supplier_site_rec.STATE := rec.STATE;
            l_supplier_site_rec.COUNTY := rec.COUNTY;
            l_supplier_site_rec.PROVINCE := rec.PROVINCE;
            l_supplier_site_rec.COUNTRY := rec.COUNTRY;
            l_supplier_site_rec.ZIP := rec.ZIP;
            l_supplier_site_rec.AREA_CODE := rec.AREA_CODE;
            l_supplier_site_rec.PHONE := rec.PHONE;
            l_supplier_site_rec.TERMS_ID := l_term_id;
            l_supplier_site_rec.PURCHASING_SITE_FLAG := 'Y';
            l_supplier_site_rec.PAY_SITE_FLAG := 'Y';
            l_supplier_site_rec.INVOICE_CURRENCY_CODE := rec.INVOICE_CURRENCY_CODE;
            l_supplier_site_rec.PAYMENT_CURRENCY_CODE := rec.PAYMENT_CURRENCY_CODE;
            l_supplier_site_rec.ORG_ID := l_org_id;
            l_supplier_site_rec.LANGUAGE := fnd_global.nls_language;
            l_supplier_site_rec.EMAIL_ADDRESS := rec.EMAIL_ADDRESS;
            l_supplier_site_rec.PRIMARY_PAY_SITE_FLAG := 'Y';
            l_supplier_site_rec.ext_payee_rec.Default_Pmt_method := l_payment_method;

            ap_vendor_pub_pkg.create_vendor_site(
              p_api_version        => 1.0,
              p_init_msg_list      => fnd_api.g_false,
              p_commit             => fnd_api.g_false,
              p_validation_level   => fnd_api.g_valid_level_full,
              x_return_status      => l_api_return_status,
              x_msg_count          => l_msg_count,
              x_msg_data           => l_msg_data,
              p_vendor_site_rec    => l_supplier_site_rec,
              x_vendor_site_id     => l_vendor_site_id,
              x_party_site_id      => l_party_site_id,
              x_location_id        => l_location_id
            );

            IF l_api_return_status != fnd_api.g_ret_sts_success THEN
              l_err_flg := 'E';
              l_err_msg := 'Error creating site: ' || FND_MSG_PUB.get(p_msg_index => 1, p_encoded => FND_API.G_FALSE);
              GOTO error_handler;
            END IF;

         
          EXCEPTION
            WHEN OTHERS THEN
              l_err_flg := 'E';
              l_err_msg := 'Exception in site creation: ' || SQLERRM;
              GOTO error_handler;
          END;

          -- Contact Creation
          BEGIN
            IF rec.CONTACT_FIRST_NAME IS NOT NULL OR rec.CONTACT_LAST_NAME IS NOT NULL THEN
              l_contact_rec.VENDOR_ID := l_vendor_id;
              l_contact_rec.VENDOR_SITE_ID := l_vendor_site_id;
              l_contact_rec.VENDOR_SITE_CODE := rec.VENDOR_SITE_CODE;
              l_contact_rec.ORG_ID := l_org_id;
              l_contact_rec.OPERATING_UNIT_NAME := rec.OPERATING_UNIT_NAME;
              l_contact_rec.PERSON_FIRST_NAME := rec.CONTACT_FIRST_NAME;
              l_contact_rec.PERSON_LAST_NAME := rec.CONTACT_LAST_NAME;
              l_contact_rec.AREA_CODE := rec.AREA_CODE;
              l_contact_rec.PHONE := rec.PHONE;
              l_contact_rec.EMAIL_ADDRESS := rec.EMAIL_ADDRESS;
              l_contact_rec.VENDOR_CONTACT_INTERFACE_ID := ln_contact_interface_id;

              ap_vendor_pub_pkg.Create_Vendor_Contact(
                p_api_version        => 1.0,
                p_init_msg_list      => fnd_api.g_false,
                p_commit             => fnd_api.g_false,
                p_validation_level   => fnd_api.g_valid_level_full,
                x_return_status      => l_api_return_status,
                x_msg_count          => l_msg_count,
                x_msg_data           => l_msg_data,
                p_vendor_contact_rec => l_contact_rec,
                x_vendor_contact_id  => l_vendor_contact_id,
                x_per_party_id       => l_party_id,
                x_rel_party_id       => l_rel_party_id,
                x_rel_id             => l_rel_id,
                x_org_contact_id     => l_org_contact_id,
                x_party_site_id      => l_party_site_id
              );

              IF l_api_return_status != fnd_api.g_ret_sts_success THEN
                l_err_flg := 'E';
                l_err_msg := 'Error creating contact: ' || FND_MSG_PUB.get(p_msg_index => 1, p_encoded => FND_API.G_FALSE);
                GOTO error_handler;
              END IF;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              l_err_flg := 'E';
              l_err_msg := 'Exception in contact creation: ' || SQLERRM;
              GOTO error_handler;
          END;

          -- Update staging table on success
          UPDATE XXRP_SUPPLIER_CONV_STG
          SET PROCESS_STATUS = 'Y',
              VENDOR_ID = l_vendor_id,
              VENDOR_SITE_ID = l_vendor_site_id,
              PARTY_ID = l_party_id,
              PARTY_SITE_ID = l_party_site_id,
              LOCATION_ID = l_location_id,
              ORG_ID = l_org_id,
              TERMS_ID = l_term_id,
              LAST_UPDATED_DATE = SYSDATE,
              LAST_UPDATED_BY = FND_GLOBAL.USER_ID
          WHERE VENDOR_NAME = rec.VENDOR_NAME
            AND VENDOR_SITE_CODE = rec.VENDOR_SITE_CODE
            AND REQUEST_ID = P_REQUEST_ID;
          COMMIT;
        END;
      END IF;

      <<error_handler>>
      IF l_err_flg = 'E' THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG, 'Error: ' || l_err_msg);
        UPDATE XXRP_SUPPLIER_CONV_STG
        SET PROCESS_STATUS = 'E',
            ERROR_MSG = SUBSTR(l_err_msg, 1, 4000),
            LAST_UPDATED_DATE = SYSDATE,
            LAST_UPDATED_BY = FND_GLOBAL.USER_ID
        WHERE VENDOR_NAME = rec.VENDOR_NAME
          AND VENDOR_SITE_CODE = rec.VENDOR_SITE_CODE
          AND REQUEST_ID = P_REQUEST_ID;
        ROLLBACK;
      END IF;
    END LOOP;

    -- Final output
    IF l_err_flg IS NULL THEN
      ERRBUFF := 'Success';
      RETCODE := 0;
    ELSE
      ERRBUFF := 'Errors occurred. Check log for details.';
      RETCODE := 2;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      ERRBUFF := 'Unexpected error: ' || SQLERRM;
      RETCODE := 2;
      FND_FILE.PUT_LINE(FND_FILE.LOG, ERRBUFF);
      ROLLBACK;
  END MAIN;
END XX_RP_SUP_API_PKG;
/
