*** Settings ***
Library           SeleniumLibrary
Library           DateTime

*** Variables ***
${URL}            https://www.saucedemo.com
${BROWSER}        Chrome
${USERNAME}       standard_user
${PASSWORD}       secret_sauce
${TIMEOUT}        10
${SEPARATOR}      ==============================================================

*** Comments ***
Check Website Availability
    [Documentation]    Test untuk mengecek apakah website dapat diakses
    [Tags]    smoke
    ${CURRENT_TIME}=    Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    Log To Console    ${\n}${SEPARATOR}
    Log To Console    Running test at: ${CURRENT_TIME}
    Log To Console    ${SEPARATOR}${\n}
    
    TRY
        Log To Console    Opening browser...
        Open Browser    ${URL}    ${BROWSER}
        Maximize Browser Window
        Log To Console    Browser opened successfully
        
        Log To Console    Checking page elements...
        Wait Until Page Contains Element    id:login-button    timeout=${TIMEOUT}
        Page Should Contain Element    id:login-button
        Log To Console    ✓ Website is accessible and login button found
        
        Close Browser
        Log To Console    ✓ Test completed successfully
        
    EXCEPT    AS    ${error}
        Log To Console    ✗ Test failed: ${error}
        Run Keyword And Ignore Error    Close Browser
        Fail    ${error}
    END

*** Test Cases ***

Login Test
    [Documentation]    Test untuk login ke website
    [Tags]    login
    ${CURRENT_TIME}=    Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    
    TRY
        Log To Console    ${\n}Starting login test...
        Open Browser    ${URL}    ${BROWSER}
        Maximize Browser Window
        Set Selenium Speed    0.5 seconds
        Log To Console    Browser opened
        
        Log To Console    Entering credentials...
        Input Text    id:user-name    ${USERNAME}
        Input Text    id:password    ${PASSWORD}
        Log To Console    Credentials entered
        
        Log To Console    Clicking login button...
        Click Button    id:login-button
        
        Log To Console    Waiting for products page...
        Wait Until Page Contains Element    class:inventory_list    timeout=${TIMEOUT}
        Page Should Contain Element    class:inventory_list
        Log To Console    ✓ Login successful
        
        Page Should Contain Element    class:inventory_item
        Log To Console    ✓ Products are visible
        
        Close Browser
        
        Log To Console    ${\n}✓ All tests completed successfully!
        Log To Console    ${SEPARATOR}${\n}
        
    EXCEPT    AS    ${error}
        Log To Console    ✗ Login test failed: ${error}
        Run Keyword And Ignore Error    Close Browser
        Fail    ${error}
    END