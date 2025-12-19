*** Settings ***
Library    RPA.Browser.Selenium
Library    RPA.Tables
Library    RPA.Excel.Files
Library    BuiltIn
Library    OperatingSystem
Library    Collections
Library    String
Library    DateTime

*** Variables ***
${URL}           https://pegadaian.co.id/
${harga_jual}    xpath=//div[@class='box-jual-beli__left']//span[normalize-space(.)='/ 0,01 gr']/parent::p
${harga_beli}    xpath=//div[contains(@class,'flex') and contains(@class,'space-x-2')]//span[normalize-space(.)='/ 0,01 gr']/parent::p

*** Tasks ***
Ambil Harga Emas Pegadaian dan Buat Laporan
    ${today}=    Get Time    result_format=%Y/%m/%d
    ${today_datetime}=    Get Time    result_format=%Y-%m-%d %H:%M:%S

    # Buka browser dan ambil data
    Open Available Browser    https://www.pegadaian.co.id    maximized=True
    Wait Until Page Contains Element    xpath=//h5[contains(., "Harga")]
    Sleep    3s
    Scroll Element Into View    ${harga_beli}
    
    ${harga_beli_text}=    Get Text    ${harga_beli}
    ${harga_jual_text}=    Get Text    ${harga_jual}
    
    ${harga_beli_numeric}=    Extract Numeric Value    ${harga_beli_text}
    ${harga_jual_numeric}=    Extract Numeric Value    ${harga_jual_text}
    
    Log    \n==============================================\n    console=True
    Log To Console    Harga Beli Emas Saat Ini: ${harga_beli_text} (${harga_beli_numeric})
    Log To Console    Harga Jual Emas Saat Ini: ${harga_jual_text} (${harga_jual_numeric})
    Log    \n==============================================\n    console=True

    # Proses Excel
    ${excel_exists}=    Run Keyword And Return Status    File Should Exist    emas.xlsx
    ${all_data}=    Create List

    IF    ${excel_exists}
        # Baca data lama
        ${old_data}=    Read Excel Data
        ${all_data}=    Set Variable    ${old_data}
        
        ${old_data_count}=    Get Length    ${old_data}
        ${panah_beli}=    Set Variable    -
        ${panah_jual}=    Set Variable    -
        
        IF    ${old_data_count} > 0
            ${data_terbaru}=    Get From List    ${old_data}    0
            ${harga_beli_sebelumnya_text}=    Get From Dictionary    ${data_terbaru}    Harga Beli
            ${harga_jual_sebelumnya_text}=    Get From Dictionary    ${data_terbaru}    Harga Jual
            
            ${beli_sebelumnya}=    Extract Numeric Value    ${harga_beli_sebelumnya_text}
            ${jual_sebelumnya}=    Extract Numeric Value    ${harga_jual_sebelumnya_text}
            
            ${panah_beli}=    Determine Arrow    ${harga_beli_numeric}    ${beli_sebelumnya}
            ${panah_jual}=    Determine Arrow    ${harga_jual_numeric}    ${jual_sebelumnya}
        END
        
        # Buat data baru
        &{new_row}=    Create Dictionary
        ...    Tanggal=${today_datetime}
        ...    Harga Beli=${harga_beli_text}
        ...    Perubahan Beli=${panah_beli}
        ...    Harga Jual=${harga_jual_text}
        ...    Perubahan Jual=${panah_jual}
        
        Insert Into List    ${all_data}    0    ${new_row}
        
        # Simpan ke Excel
        Save To Excel    ${all_data}
        
        Log    \n✅ Data berhasil diperbarui di Excel    console=True
    ELSE
        # Buat data pertama
        &{first_row}=    Create Dictionary
        ...    Tanggal=${today_datetime}
        ...    Harga Beli=${harga_beli_text}
        ...    Perubahan Beli=-
        ...    Harga Jual=${harga_jual_text}
        ...    Perubahan Jual=-
        
        ${all_data}=    Create List    ${first_row}
        Save To Excel    ${all_data}
        
        Log    \n✅ File Excel baru dibuat    console=True
    END

    # Buat laporan HTML dengan GRAFIK SEDERHANA
    Create HTMLWithSimpleChart    ${all_data}
    
    [Teardown]    Close All Browsers

*** Keywords ***
Extract Numeric Value
    [Arguments]    ${text}
    
    ${cleaned}=    Get Regexp Matches    ${text}    ([0-9.,]+)    1
    
    IF    not ${cleaned}
        Log    Warning: No numeric value found in: ${text}    console=True
        RETURN    ${0}
    END
    
    ${cleaned}=    Set Variable    ${cleaned}[0]
    
    # Hapus titik sebagai pemisah ribuan
    ${cleaned}=    Replace String    ${cleaned}    .    ${EMPTY}
    # Ganti koma dengan titik sebagai separator desimal
    ${cleaned}=    Replace String    ${cleaned}    ,    .
    ${cleaned}=    Strip String    ${cleaned}
    
    ${numeric}=    Convert To Number    ${cleaned}
    RETURN    ${numeric}

Determine Arrow
    [Arguments]    ${harga_sekarang}    ${harga_sebelumnya}
    
    IF    ${harga_sebelumnya} == 0
        RETURN    -
    ELSE IF    ${harga_sekarang} == ${harga_sebelumnya}
        RETURN    -
    ELSE IF    ${harga_sekarang} > ${harga_sebelumnya}
        RETURN    ▲
    ELSE
        RETURN    ▼
    END

Read Excel Data
    ${data}=    Create List
    
    TRY
        Open Workbook    emas.xlsx
        ${sheets}=    List Worksheets
        
        # Cari worksheet Harga_Barang
        ${harga_barang_exists}=    Set Variable    ${False}
        FOR    ${sheet}    IN    @{sheets}
            IF    '${sheet}' == 'Harga_Barang'
                ${harga_barang_exists}=    Set Variable    ${True}
                Exit For Loop
            END
        END
        
        IF    ${harga_barang_exists}
            ${worksheet_data}=    Read Worksheet    name=Harga_Barang    header=True
            FOR    ${row}    IN    @{worksheet_data}
                Append To List    ${data}    ${row}
            END
        END
        
        Close Workbook
        Log    Successfully read ${data} rows from Excel    console=True
    EXCEPT    AS    ${error}
        Log    Error reading Excel: ${error}    console=True
        ${data}=    Create List
    END
    
    RETURN    ${data}

Save To Excel
    [Arguments]    ${data}
    
    TRY
        Create Workbook    emas.xlsx
        Create Worksheet    name=Harga_Barang    content=${data}    header=True
        
        # Hapus sheet default jika ada
        ${sheets}=    List Worksheets
        FOR    ${sheet}    IN    @{sheets}
            IF    '${sheet}' in ['Sheet', 'Sheet1'] and '${sheet}' != 'Harga_Barang'
                Remove Worksheet    name=${sheet}
            END
        END
        
        Save Workbook
        Close Workbook
        Log    Successfully saved ${data} rows to Excel    console=True
    EXCEPT    AS    ${error}
        Log    Error saving Excel: ${error}    console=True
    END

Create HTMLWithSimpleChart
    [Arguments]    ${data}
    
    ${current_time}=    Get Time    result_format=%Y-%m-%d %H:%M:%S
    
    # PERBAIKAN: Cek data sebelum diproses
    ${data_count}=    Get Length    ${data}
    Log    \n📊 Data count for chart: ${data_count}    console=True
    
    IF    ${data_count} == 0
        Log    Warning: No data available for HTML report    console=True
        RETURN
    END
    
    # LOG DATA AWAL untuk debugging
    Log    \n=== DATA AWAL UNTUK CHART ===    console=True
    FOR    ${index}    ${row}    IN ENUMERATE    @{data}
        ${num}=    Evaluate    ${index} + 1
        Log    Data ${num}: Tanggal=${row}[Tanggal] | Beli=${row}[Harga Beli] | Jual=${row}[Harga Jual]    console=True
    END
    
    ${current_data}=    Get From List    ${data}    0
    ${stats}=    Calculate Statistics    ${data}
    
    # Siapkan data untuk chart dengan sorting yang benar
    ${chart_data}=    PrepareSimpleChartData    ${data}
    
    # Debug: Cek struktur chart_data
    Log    \n=== CHART DATA STRUCTURE ===    console=True
    Log    Labels: ${chart_data}[labels]    console=True
    Log    Beli: ${chart_data}[beli]    console=True
    Log    Jual: ${chart_data}[jual]    console=True
    
    # Tentukan class perubahan
    ${beli_change_class}=    Get Change Class    ${current_data}[Perubahan Beli]
    ${jual_change_class}=    Get Change Class    ${current_data}[Perubahan Jual]
    
    # Mulai buat HTML
    ${html}=    Set Variable    <!DOCTYPE html>
    ${html}=    Catenate    SEPARATOR=    ${html}    <html>
    ${html}=    Catenate    SEPARATOR=    ${html}    <head>
    ${html}=    Catenate    SEPARATOR=    ${html}    <title>Laporan Harga Emas Pegadaian</title>
    ${html}=    Catenate    SEPARATOR=    ${html}    <meta charset="UTF-8">
    ${html}=    Catenate    SEPARATOR=    ${html}    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    ${html}=    Catenate    SEPARATOR=    ${html}    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    ${html}=    Catenate    SEPARATOR=    ${html}    <style>
    ${html}=    Catenate    SEPARATOR=    ${html}    body { font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .container { max-width: 1200px; margin: auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
    ${html}=    Catenate    SEPARATOR=    ${html}    h1 { color: #2c3e50; text-align: center; }
    ${html}=    Catenate    SEPARATOR=    ${html}    h2 { color: #34495e; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .current-prices { display: flex; gap: 20px; margin: 20px 0; flex-wrap: wrap; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .price-card { flex: 1; min-width: 200px; padding: 20px; border: 1px solid #ddd; border-radius: 8px; text-align: center; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    ${html}=    Catenate    SEPARATOR=    ${html}    .price { font-size: 28px; font-weight: bold; color: #2c3e50; margin: 10px 0; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .change { font-size: 24px; margin-top: 10px; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .naik { color: green; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .turun { color: red; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .stabil { color: gray; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .stats { display: flex; gap: 20px; margin: 20px 0; flex-wrap: wrap; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .stat-item { flex: 1; min-width: 250px; padding: 20px; background: #f8f9fa; border-radius: 8px; text-align: center; border: 1px solid #ddd; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .stat-value { font-size: 32px; font-weight: bold; color: #2c3e50; margin: 10px 0; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .stat-label { color: #666; font-size: 16px; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .chart-container { 
    ${html}=    Catenate    SEPARATOR=    ${html}    margin: 30px 0; 
    ${html}=    Catenate    SEPARATOR=    ${html}    padding: 25px; 
    ${html}=    Catenate    SEPARATOR=    ${html}    border: 1px solid #e5e7eb; 
    ${html}=    Catenate    SEPARATOR=    ${html}    border-radius: 12px; 
    ${html}=    Catenate    SEPARATOR=    ${html}    background: white; 
    ${html}=    Catenate    SEPARATOR=    ${html}    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06); 
    ${html}=    Catenate    SEPARATOR=    ${html}    position: relative; 
    ${html}=    Catenate    SEPARATOR=    ${html}    } 
    ${html}=    Catenate    SEPARATOR=    ${html}    #priceChart { 
    ${html}=    Catenate    SEPARATOR=    ${html}    width: 100% !important; 
    ${html}=    Catenate    SEPARATOR=    ${html}    height: 500px !important; 
    ${html}=    Catenate    SEPARATOR=    ${html}    } 
    ${html}=    Catenate    SEPARATOR=    ${html}    .chart-loading { 
    ${html}=    Catenate    SEPARATOR=    ${html}    position: absolute; 
    ${html}=    Catenate    SEPARATOR=    ${html}    top: 50%; 
    ${html}=    Catenate    SEPARATOR=    ${html}    left: 50%; 
    ${html}=    Catenate    SEPARATOR=    ${html}    transform: translate(-50%, -50%); 
    ${html}=    Catenate    SEPARATOR=    ${html}    color: #6b7280; 
    ${html}=    Catenate    SEPARATOR=    ${html}    font-size: 16px; 
    ${html}=    Catenate    SEPARATOR=    ${html}    } 
    ${html}=    Catenate    SEPARATOR=    ${html}    .chart-error { 
    ${html}=    Catenate    SEPARATOR=    ${html}    background: #fee2e2; 
    ${html}=    Catenate    SEPARATOR=    ${html}    color: #dc2626; 
    ${html}=    Catenate    SEPARATOR=    ${html}    padding: 16px; 
    ${html}=    Catenate    SEPARATOR=    ${html}    border-radius: 8px; 
    ${html}=    Catenate    SEPARATOR=    ${html}    text-align: center; 
    ${html}=    Catenate    SEPARATOR=    ${html}    margin: 10px 0; 
    ${html}=    Catenate    SEPARATOR=    ${html}    border: 1px solid #fca5a5; 
    ${html}=    Catenate    SEPARATOR=    ${html}    font-size: 14px; 
    ${html}=    Catenate    SEPARATOR=    ${html}    } 
    ${html}=    Catenate    SEPARATOR=    ${html}    table { width: 100%; border-collapse: collapse; margin-top: 30px; }
    ${html}=    Catenate    SEPARATOR=    ${html}    th, td { border: 1px solid #ddd; padding: 12px; text-align: center; }
    ${html}=    Catenate    SEPARATOR=    ${html}    th { background: #4CAF50; color: white; font-weight: bold; }
    ${html}=    Catenate    SEPARATOR=    ${html}    tr:nth-child(even) { background: #f9f9f9; }
    ${html}=    Catenate    SEPARATOR=    ${html}    tr:hover { background: #f1f1f1; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; text-align: center; color: #666; font-size: 14px; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .logo { text-align: center; margin-bottom: 20px; }
    ${html}=    Catenate    SEPARATOR=    ${html}    .logo img { max-height: 60px; }
    ${html}=    Catenate    SEPARATOR=    ${html}    </style>
    ${html}=    Catenate    SEPARATOR=    ${html}    </head>
    ${html}=    Catenate    SEPARATOR=    ${html}    <body>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="container">
    
    # Logo/Header
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="logo">
    ${html}=    Catenate    SEPARATOR=    ${html}    <h1>📊 Laporan Harga Emas Pegadaian</h1>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    
    # Harga Saat Ini
    ${html}=    Catenate    SEPARATOR=    ${html}    <h2>💰 Harga Saat Ini</h2>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="current-prices">
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="price-card">
    ${html}=    Catenate    SEPARATOR=    ${html}    <h3>Harga Beli</h3>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="price">${current_data}[Harga Beli]</div>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="change ${beli_change_class}">${current_data}[Perubahan Beli]</div>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="price-card">
    ${html}=    Catenate    SEPARATOR=    ${html}    <h3>Harga Jual</h3>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="price">${current_data}[Harga Jual]</div>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="change ${jual_change_class}">${current_data}[Perubahan Jual]</div>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    
    # Statistik
    ${html}=    Catenate    SEPARATOR=    ${html}    <h2>📈 Statistik</h2>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="stats">
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="stat-item">
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="stat-value">${stats}[avg_beli]</div>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="stat-label">Rata-rata Beli</div>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="stat-item">
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="stat-value">${stats}[avg_jual]</div>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="stat-label">Rata-rata Jual</div>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    
    # Grafik
    ${html}=    Catenate    SEPARATOR=    ${html}    <h2>📊 Grafik Perkembangan Harga</h2>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="chart-container">
    ${html}=    Catenate    SEPARATOR=    ${html}    <canvas id="priceChart"></canvas>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div id="chartLoading" class="chart-loading">Memuat grafik...</div>
    ${html}=    Catenate    SEPARATOR=    ${html}    <div id="chartError" class="chart-error" style="display: none;"></div>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    
    # Tabel Data
    ${html}=    Catenate    SEPARATOR=    ${html}    <h2>📋 Data Historis</h2>
    ${html}=    Catenate    SEPARATOR=    ${html}    <table id="dataTable">
    ${html}=    Catenate    SEPARATOR=    ${html}    <thead>
    ${html}=    Catenate    SEPARATOR=    ${html}    <tr>
    ${html}=    Catenate    SEPARATOR=    ${html}    <th>No</th>
    ${html}=    Catenate    SEPARATOR=    ${html}    <th>Tanggal & Waktu</th>
    ${html}=    Catenate    SEPARATOR=    ${html}    <th>Harga Beli</th>
    ${html}=    Catenate    SEPARATOR=    ${html}    <th>Perubahan</th>
    ${html}=    Catenate    SEPARATOR=    ${html}    <th>Harga Jual</th>
    ${html}=    Catenate    SEPARATOR=    ${html}    <th>Perubahan</th>
    ${html}=    Catenate    SEPARATOR=    ${html}    </tr>
    ${html}=    Catenate    SEPARATOR=    ${html}    </thead>
    ${html}=    Catenate    SEPARATOR=    ${html}    <tbody>
    
    # Tambahkan baris data
    ${row_number}=    Set Variable    1
    FOR    ${row}    IN    @{data}
        ${row_beli_class}=    Get Change Class    ${row}[Perubahan Beli]
        ${row_jual_class}=    Get Change Class    ${row}[Perubahan Jual]
        
        ${html}=    Catenate    SEPARATOR=    ${html}    <tr>
        ${html}=    Catenate    SEPARATOR=    ${html}    <td>${row_number}</td>
        ${html}=    Catenate    SEPARATOR=    ${html}    <td>${row}[Tanggal]</td>
        ${html}=    Catenate    SEPARATOR=    ${html}    <td>${row}[Harga Beli]</td>
        ${html}=    Catenate    SEPARATOR=    ${html}    <td class="${row_beli_class}"><strong>${row}[Perubahan Beli]</strong></td>
        ${html}=    Catenate    SEPARATOR=    ${html}    <td>${row}[Harga Jual]</td>
        ${html}=    Catenate    SEPARATOR=    ${html}    <td class="${row_jual_class}"><strong>${row}[Perubahan Jual]</strong></td>
        ${html}=    Catenate    SEPARATOR=    ${html}    </tr>
        
        ${row_number}=    Evaluate    ${row_number} + 1
    END
    
    ${html}=    Catenate    SEPARATOR=    ${html}    </tbody>
    ${html}=    Catenate    SEPARATOR=    ${html}    </table>
    
    # Footer
    ${html}=    Catenate    SEPARATOR=    ${html}    <div class="footer">
    ${html}=    Catenate    SEPARATOR=    ${html}    <p><strong>Laporan dibuat:</strong> ${current_time}</p>
    ${html}=    Catenate    SEPARATOR=    ${html}    <p><strong>Sumber data:</strong> <a href="https://www.pegadaian.co.id" target="_blank">Pegadaian.co.id</a></p>
    ${html}=    Catenate    SEPARATOR=    ${html}    <p><strong>Total Data:</strong> ${row_number} records</p>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    ${html}=    Catenate    SEPARATOR=    ${html}    </div>
    
    # JavaScript untuk Chart yang DIPERBAIKI
    ${javascript}=    CreateSimpleChartJS    ${chart_data}
    ${html}=    Catenate    SEPARATOR=    ${html}    ${javascript}
    
    ${html}=    Catenate    SEPARATOR=    ${html}    </body>
    ${html}=    Catenate    SEPARATOR=    ${html}    </html>
    
    # Simpan file
    Create File    laporan_emas.html    ${html}
    Log    \n✅ Laporan dengan grafik dibuat: laporan_emas.html    console=True
    Log    📍 Buka file untuk melihat grafik dari data historis!    console=True

PrepareSimpleChartData
    [Arguments]    ${data}
    
    Log    \n=== DEBUG CHART DATA ===    console=True
    
    ${labels}=    Create List
    ${beli_data}=    Create List
    ${jual_data}=    Create List
    
    ${count}=    Get Length    ${data}
    Log    Total data count: ${count}    console=True
    
    IF    ${count} == 0
        Log    Warning: No data available for chart    console=True
        &{empty_result}=    Create Dictionary
        ...    labels=[]
        ...    beli=[]
        ...    jual=[]
        RETURN    ${empty_result}
    END
    
    # PERBAIKAN: Sort data dari terlama ke terbaru untuk chart yang benar
    ${sorted_data}=    SortDataByDate    ${data}
    
    # Ambil 10 data TERAKHIR (terbaru) setelah di-sort
    ${max_points}=    Evaluate    min(${count}, 10)
    Log    Max points for chart: ${max_points}    console=True
    
    # Ambil 10 data terakhir dari data yang sudah di-sort
    ${start_index}=    Evaluate    ${count} - ${max_points}
    
    FOR    ${i}    IN RANGE    ${start_index}    ${count}
        ${row}=    Get From List    ${sorted_data}    ${i}
        
        # Ambil hanya jam:menit dari timestamp
        ${time_part}=    Get Substring    ${row}[Tanggal]    11    16
        ${time_part}=    Strip String    ${time_part}
        
        # Ekstrak nilai numerik
        ${beli_num}=    Extract Numeric Value    ${row}[Harga Beli]
        ${jual_num}=    Extract Numeric Value    ${row}[Harga Jual]
        
        Append To List    ${labels}    ${time_part}
        Append To List    ${beli_data}    ${beli_num}
        Append To List    ${jual_data}    ${jual_num}
        
        Log    Data ${i+1}: ${time_part} - Beli: ${beli_num} - Jual: ${jual_num}    console=True
    END
    
    # Format data untuk JavaScript
    ${labels_js}=    ConvertListToJSString    ${labels}
    ${beli_js}=    ConvertListToJSString    ${beli_data}    is_number=${True}
    ${jual_js}=    ConvertListToJSString    ${jual_data}    is_number=${True}
    
    Log    \n--- JavaScript Arrays ---    console=True
    Log    Labels: ${labels_js}    console=True
    Log    Beli: ${beli_js}    console=True
    Log    Jual: ${jual_js}    console=True
    
    &{result}=    Create Dictionary
    ...    labels=${labels_js}
    ...    beli=${beli_js}
    ...    jual=${jual_js}
    
    RETURN    ${result}

SortDataByDate
    [Arguments]    ${data_list}
    
    ${count}=    Get Length    ${data_list}
    IF    ${count} <= 1
        RETURN    ${data_list}
    END
    
    # Buat copy untuk sorting
    ${sorted_list}=    Create List
    FOR    ${item}    IN    @{data_list}
        Append To List    ${sorted_list}    ${item}
    END
    
    # Simple bubble sort berdasarkan tanggal (dari terlama ke terbaru)
    FOR    ${i}    IN RANGE    0    ${count}
        FOR    ${j}    IN RANGE    ${i}    ${count}
            ${item_i}=    Get From List    ${sorted_list}    ${i}
            ${item_j}=    Get From List    ${sorted_list}    ${j}
            
            ${date_i}=    Set Variable    ${item_i}[Tanggal]
            ${date_j}=    Set Variable    ${item_j}[Tanggal]
            
            # Bandingkan tanggal (format: YYYY-MM-DD HH:MM:SS)
            ${should_swap}=    Evaluate    '${date_i}' > '${date_j}'
            
            IF    ${should_swap}
                # Swap items
                Set List Value    ${sorted_list}    ${i}    ${item_j}
                Set List Value    ${sorted_list}    ${j}    ${item_i}
            END
        END
    END
    
    Log    \n✅ Data diurutkan dari terlama ke terbaru    console=True
    RETURN    ${sorted_list}

ConvertListToJSString
    [Arguments]    ${data_list}    ${is_number}=${False}
    
    ${count}=    Get Length    ${data_list}
    
    IF    ${count} == 0
        RETURN    []
    END
    
    ${js_string}=    Set Variable    [
    
    FOR    ${index}    IN RANGE    0    ${count}
        ${item}=    Get From List    ${data_list}    ${index}
        
        IF    ${is_number}
            # Angka tanpa quotes
            ${js_string}=    Catenate    SEPARATOR=    ${js_string}    ${item}
        ELSE
            # String dengan quotes
            ${js_string}=    Catenate    SEPARATOR=    ${js_string}    "${item}"
        END
        
        IF    ${index} < ${count} - 1
            ${js_string}=    Catenate    SEPARATOR=    ${js_string}    ,
        END
    END
    
    ${js_string}=    Catenate    SEPARATOR=    ${js_string}    ]
    
    RETURN    ${js_string}

CreateSimpleChartJS
    [Arguments]    ${chart_data}
    
    ${js}=    Catenate    SEPARATOR=\n
    ...    <script>
    ...    // Data untuk chart
    ...    const chartLabels = ${chart_data}[labels];
    ...    const chartBeliData = ${chart_data}[beli];
    ...    const chartJualData = ${chart_data}[jual];
    ...
    ...    console.log('=== CHART DATA DEBUG ===');
    ...    console.log('Chart Labels:', chartLabels);
    ...    console.log('Chart Beli Data:', chartBeliData);
    ...    console.log('Chart Jual Data:', chartJualData);
    ...
    ...    // Fungsi untuk membuat chart yang lebih baik
    ...    function createPriceChart() {
    ...        console.log('Creating enhanced chart...');
    ...        
    ...        // Sembunyikan loading message
    ...        const loadingDiv = document.getElementById('chartLoading');
    ...        if (loadingDiv) loadingDiv.style.display = 'none';
    ...        
    ...        const canvas = document.getElementById('priceChart');
    ...        if (!canvas) {
    ...            console.error('Canvas element not found!');
    ...            showChartError('Canvas tidak ditemukan');
    ...            return;
    ...        }
    ...
    ...        // Set ukuran canvas yang lebih besar
    ...        canvas.style.width = '100%';
    ...        canvas.style.height = '500px';
    ...
    ...        const ctx = canvas.getContext('2d');
    ...        if (!ctx) {
    ...            console.error('Cannot get 2D context');
    ...            showChartError('Konteks canvas tidak tersedia');
    ...            return;
    ...        }
    ...
    ...        // Hapus chart lama jika ada
    ...        if (window.myChart && typeof window.myChart.destroy === 'function') {
    ...            window.myChart.destroy();
    ...        }
    ...
    ...        try {
    ...            // Gradient untuk background
    ...            const gradientBeli = ctx.createLinearGradient(0, 0, 0, 400);
    ...            gradientBeli.addColorStop(0, 'rgba(59, 130, 246, 0.3)');
    ...            gradientBeli.addColorStop(1, 'rgba(59, 130, 246, 0.05)');
    ...
    ...            const gradientJual = ctx.createLinearGradient(0, 0, 0, 400);
    ...            gradientJual.addColorStop(0, 'rgba(239, 68, 68, 0.3)');
    ...            gradientJual.addColorStop(1, 'rgba(239, 68, 68, 0.05)');
    ...
    ...            window.myChart = new Chart(ctx, {
    ...                type: 'line',
    ...                data: {
    ...                    labels: chartLabels,
    ...                    datasets: [
    ...                        {
    ...                            label: 'Harga Beli',
    ...                            data: chartBeliData,
    ...                            borderColor: '#3b82f6',
    ...                            backgroundColor: gradientBeli,
    ...                            borderWidth: 3,
    ...                            fill: true,
    ...                            tension: 0.4,
    ...                            pointRadius: 6,
    ...                            pointBackgroundColor: '#3b82f6',
    ...                            pointBorderColor: '#ffffff',
    ...                            pointBorderWidth: 2,
    ...                            pointHoverRadius: 8,
    ...                            pointHoverBackgroundColor: '#1d4ed8',
    ...                            pointHoverBorderColor: '#ffffff',
    ...                            pointHoverBorderWidth: 3
    ...                        },
    ...                        {
    ...                            label: 'Harga Jual',
    ...                            data: chartJualData,
    ...                            borderColor: '#ef4444',
    ...                            backgroundColor: gradientJual,
    ...                            borderWidth: 3,
    ...                            fill: true,
    ...                            tension: 0.4,
    ...                            pointRadius: 6,
    ...                            pointBackgroundColor: '#ef4444',
    ...                            pointBorderColor: '#ffffff',
    ...                            pointBorderWidth: 2,
    ...                            pointHoverRadius: 8,
    ...                            pointHoverBackgroundColor: '#dc2626',
    ...                            pointHoverBorderColor: '#ffffff',
    ...                            pointHoverBorderWidth: 3
    ...                        }
    ...                    ]
    ...                },
    ...                options: {
    ...                    responsive: true,
    ...                    maintainAspectRatio: false,
    ...                    interaction: {
    ...                        mode: 'index',
    ...                        intersect: false
    ...                    },
    ...                    plugins: {
    ...                        title: {
    ...                            display: true,
    ...                            text: '📈 Perkembangan Harga Emas Pegadaian',
    ...                            font: {
    ...                                size: 20,
    ...                                weight: 'bold',
    ...                                family: 'Arial, sans-serif'
    ...                            },
    ...                            color: '#1f2937',
    ...                            padding: {
    ...                                top: 10,
    ...                                bottom: 30
    ...                            }
    ...                        },
    ...                        legend: {
    ...                            display: true,
    ...                            position: 'top',
    ...                            labels: {
    ...                                color: '#4b5563',
    ...                                font: {
    ...                                    size: 14,
    ...                                    weight: 'bold'
    ...                                },
    ...                                padding: 20,
    ...                                usePointStyle: true,
    ...                                pointStyle: 'circle'
    ...                            }
    ...                        },
    ...                        tooltip: {
    ...                            backgroundColor: 'rgba(31, 41, 55, 0.9)',
    ...                            titleColor: '#f9fafb',
    ...                            bodyColor: '#f9fafb',
    ...                            titleFont: {
    ...                                size: 14,
    ...                                weight: 'bold'
    ...                            },
    ...                            bodyFont: {
    ...                                size: 14
    ...                            },
    ...                            padding: 12,
    ...                            cornerRadius: 8,
    ...                            displayColors: false,
    ...                            callbacks: {
    ...                                label: function(context) {
    ...                                    let label = context.dataset.label || '';
    ...                                    const value = context.parsed.y;
    ...                                    const icon = context.dataset.label === 'Harga Beli' ? String.fromCodePoint(0x1F4B0) : String.fromCodePoint(0x1F4B5);
    ...                                    return icon + ' ' + label + ': Rp ' + value.toLocaleString('id-ID');
    ...                                },
    ...                                title: function(tooltipItems) {
    ...                                    return String.fromCodePoint(0x23F0) + ' Waktu: ' + tooltipItems[0].label;
    ...                                }
    ...                            }
    ...                        }
    ...                    },
    ...                    scales: {
    ...                        y: {
    ...                            beginAtZero: false,
    ...                            grid: {
    ...                                color: 'rgba(209, 213, 219, 0.3)',
    ...                                drawBorder: false
    ...                            },
    ...                            ticks: {
    ...                                color: '#6b7280',
    ...                                font: {
    ...                                    size: 12,
    ...                                    weight: 'bold'
    ...                                },
    ...                                padding: 10,
    ...                                callback: function(value) {
    ...                                    return 'Rp ' + value.toLocaleString('id-ID');
    ...                                }
    ...                            },
    ...                            title: {
    ...                                display: true,
    ...                                text: String.fromCodePoint(0x1F4B0) + ' Harga (Rupiah)',
    ...                                color: '#4b5563',
    ...                                font: {
    ...                                    size: 14,
    ...                                    weight: 'bold'
    ...                                },
    ...                                padding: {
    ...                                    top: 10,
    ...                                    bottom: 10
    ...                                }
    ...                            }
    ...                        },
    ...                        x: {
    ...                            grid: {
    ...                                color: 'rgba(209, 213, 219, 0.2)',
    ...                                drawBorder: false
    ...                            },
    ...                            ticks: {
    ...                                color: '#6b7280',
    ...                                font: {
    ...                                    size: 11,
    ...                                    weight: 'bold'
    ...                                },
    ...                                maxRotation: 45,
    ...                                minRotation: 45,
    ...                                padding: 10,
    ...                                callback: function(value, index) {
    ...                                    // Format label waktu dengan lebih baik
    ...                                    const label = chartLabels[index];
    ...                                    return label || value;
    ...                                }
    ...                            },
    ...                            title: {
    ...                                display: true,
    ...                                text: String.fromCodePoint(0x23F0) + ' Waktu',
    ...                                color: '#4b5563',
    ...                                font: {
    ...                                    size: 14,
    ...                                    weight: 'bold'
    ...                                },
    ...                                padding: {
    ...                                    top: 10,
    ...                                    bottom: 10
    ...                                }
    ...                            }
    ...                        }
    ...                    },
    ...                    elements: {
    ...                        line: {
    ...                            tension: 0.4
    ...                        }
    ...                    },
    ...                    animations: {
    ...                        tension: {
    ...                            duration: 1000,
    ...                            easing: 'linear'
    ...                        }
    ...                    }
    ...                }
    ...            });
    ...            
    ...            console.log('✅ Enhanced chart created successfully!');
    ...            hideChartError();
    ...            
    ...        } catch (error) {
    ...            console.error('Error creating chart:', error);
    ...            showChartError('Gagal membuat grafik: ' + error.message);
    ...        }
    ...    }
    ...
    ...    // Fungsi untuk menampilkan pesan error
    ...    function showChartError(message) {
    ...        const errorDiv = document.getElementById('chartError');
    ...        if (errorDiv) {
    ...            errorDiv.innerHTML = '<strong>⚠️ Error:</strong> ' + message;
    ...            errorDiv.style.display = 'block';
    ...        }
    ...    }
    ...
    ...    // Fungsi untuk menyembunyikan error
    ...    function hideChartError() {
    ...        const errorDiv = document.getElementById('chartError');
    ...        if (errorDiv) {
    ...            errorDiv.style.display = 'none';
    ...        }
    ...    }
    ...
    ...    // Inisialisasi chart
    ...    function initializeChart() {
    ...        if (typeof Chart === 'undefined') {
    ...            console.log('Chart.js belum dimuat, menunggu...');
    ...            setTimeout(initializeChart, 100);
    ...            return;
    ...        }
    ...
    ...        console.log('Chart.js siap, membuat chart...');
    ...        if (document.readyState === 'loading') {
    ...            document.addEventListener('DOMContentLoaded', createPriceChart);
    ...        } else {
    ...            createPriceChart();
    ...        }
    ...    }
    ...
    ...    // Mulai inisialisasi
    ...    initializeChart();
    ...    </script>
    
    RETURN    ${js}

Calculate Statistics
    [Arguments]    ${data}
    
    ${total_beli}=    Set Variable    ${0}
    ${total_jual}=    Set Variable    ${0}
    ${count}=    Get Length    ${data}
    
    IF    ${count} == 0
        &{stats}=    Create Dictionary
        ...    avg_beli=0
        ...    avg_jual=0
        RETURN    ${stats}
    END
    
    FOR    ${row}    IN    @{data}
        ${harga_beli}=    Extract Numeric Value    ${row}[Harga Beli]
        ${harga_jual}=    Extract Numeric Value    ${row}[Harga Jual]
        
        ${total_beli}=    Evaluate    ${total_beli} + ${harga_beli}
        ${total_jual}=    Evaluate    ${total_jual} + ${harga_jual}
    END
    
    # Hitung rata-rata
    ${avg_beli}=    Evaluate    round(${total_beli} / ${count}, 2) if ${count} > 0 else 0
    ${avg_jual}=    Evaluate    round(${total_jual} / ${count}, 2) if ${count} > 0 else 0
    
    # Format angka - PERBAIKAN: Gunakan format sederhana
    ${avg_beli_formatted}=    Evaluate    "{:.2f}".format(${avg_beli})
    ${avg_jual_formatted}=    Evaluate    "{:.2f}".format(${avg_jual})
    
    &{stats}=    Create Dictionary
    ...    avg_beli=${avg_beli_formatted}
    ...    avg_jual=${avg_jual_formatted}
    
    RETURN    ${stats}

Get Change Class
    [Arguments]    ${symbol}
    
    IF    '${symbol}' == '▲'
        RETURN    naik
    ELSE IF    '${symbol}' == '▼'
        RETURN    turun
    ELSE
        RETURN    stabil
    END

Reverse Data List
    [Arguments]    ${data_list}
    
    ${reversed}=    Create List
    ${length}=    Get Length    ${data_list}
    
    # Loop dari akhir ke awal
    FOR    ${index}    IN RANGE    ${length}
        ${reverse_index}=    Evaluate    ${length} - ${index} - 1
        ${item}=    Get From List    ${data_list}    ${reverse_index}
        Append To List    ${reversed}    ${item}
    END
    
    RETURN    ${reversed}

Reverse List
    [Arguments]    ${data_list}
    
    ${reversed}=    Create List
    ${length}=    Get Length    ${data_list}
    
    FOR    ${index}    IN RANGE    ${length}
        ${reverse_index}=    Evaluate    ${length} - ${index} - 1
        ${item}=    Get From List    ${data_list}    ${reverse_index}
        Append To List    ${reversed}    ${item}
    END
    
    RETURN    ${reversed}