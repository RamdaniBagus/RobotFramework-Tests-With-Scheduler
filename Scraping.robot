*** Settings ***
Library    RPA.Browser.Selenium
Library    RPA.Tables
Library    RPA.Excel.Files
Library    BuiltIn
Library    OperatingSystem
Library    Collections
Library    String

*** Variables ***
${URL}           https://pegadaian.co.id/
${Tabel_TabunganEmas}    class=gold-section-box__left-top
${LAPORAN_TXT}   C:\\temp\\laporan_emas_pegadaian.txt
${harga_jual}    xpath=//div[@class='box-jual-beli__left']//span[normalize-space(.)='/ 0,01 gr']/parent::p
${harga_beli}    xpath=//div[contains(@class,'flex') and contains(@class,'space-x-2')]//span[normalize-space(.)='/ 0,01 gr']/parent::p

*** Tasks ***
Ambil Harga Emas Pegadaian dan Buat Laporan
    ${today}=    Get Time    result_format=%Y/%m/%d
    
    # Format tanggal lebih baik untuk perbandingan
    ${today_datetime}=    Get Time    result_format=%Y-%m-%d %H:%M:%S

    Open Available Browser    https://www.pegadaian.co.id    maximized=True
    Wait Until Page Contains Element    xpath=//h5[contains(., "Harga")]
    Scroll Element Into View    ${harga_beli}
    
    # Ambil hanya angka dari harga
    ${harga_beli_text}=    Get Text    ${harga_beli}
    ${harga_jual_text}=    Get Text    ${harga_jual}
    
    # Ekstrak nilai numerik dari harga (hilangkan Rp, titik, koma, dan satuan)
    ${harga_beli_numeric}=    Extract Numeric Value    ${harga_beli_text}
    ${harga_jual_numeric}=    Extract Numeric Value    ${harga_jual_text}
    
    Log    \n==============================================\n    console=True
    Log To Console    Harga Beli Emas Saat Ini: ${harga_beli_text} (${harga_beli_numeric})
    Log To Console    Harga Jual Emas Saat Ini: ${harga_jual_text} (${harga_jual_numeric})
    Log    \n==============================================\n    console=True

    # === Excel ===
    ${excel_exists}=    Run Keyword And Return Status
    ...    File Should Exist    emas.xlsx

    # Inisialisasi variabel untuk perbandingan
    ${beli_sebelumnya}=    Set Variable    ${0}
    ${jual_sebelumnya}=    Set Variable    ${0}
    ${panah_beli}=    Set Variable    ${EMPTY}
    ${panah_jual}=    Set Variable    ${EMPTY}

    IF    ${excel_exists}
        # Baca data dari file yang ada
        ${all_data}=    Create List
        
        # Buka workbook lama hanya untuk membaca
        Open Workbook    emas.xlsx
        
        # Cek apakah worksheet Harga_Barang ada
        ${sheets}=    List Worksheets
        ${harga_barang_exists}=    Evaluate    'Harga_Barang' in ${sheets}
        
        IF    ${harga_barang_exists}
            # Baca data lama dengan header
            ${old_data}=    Read Worksheet    name=Harga_Barang    header=True
            
            # Cek apakah ada data sebelumnya untuk perbandingan
            ${old_data_count}=    Get Length    ${old_data}
            IF    ${old_data_count} > 0
                # Ambil data pertama (terbaru) untuk perbandingan
                ${data_terbaru}=    Get From List    ${old_data}    0
                
                # Coba ekstrak nilai numerik dari data sebelumnya
                ${harga_beli_sebelumnya_text}=    Get From Dictionary    ${data_terbaru}    Harga Beli
                ${harga_jual_sebelumnya_text}=    Get From Dictionary    ${data_terbaru}    Harga Jual
                
                ${beli_sebelumnya}=    Extract Numeric Value    ${harga_beli_sebelumnya_text}
                ${jual_sebelumnya}=    Extract Numeric Value    ${harga_jual_sebelumnya_text}
                
                # Tentukan tanda panah berdasarkan perbandingan
                ${panah_beli}=    Determine Arrow    ${harga_beli_numeric}    ${beli_sebelumnya}
                ${panah_jual}=    Determine Arrow    ${harga_jual_numeric}    ${jual_sebelumnya}
                
                # Tambahkan ke semua data
                FOR    ${row}    IN    @{old_data}
                    Append To List    ${all_data}    ${row}
                END
            END
        END
        
        # Tutup workbook lama
        Close Workbook
        
        # Buat data baru dengan kolom Perubahan
        &{new_row}=    Create Dictionary
        ...    Tanggal=${today_datetime}
        ...    Harga Beli=${harga_beli_text}
        ...    Perubahan Beli=${panah_beli}
        ...    Harga Jual=${harga_jual_text}
        ...    Perubahan Jual=${panah_jual}
        
        # Sisipkan data baru di awal
        Insert Into List    ${all_data}    0    ${new_row}
        
        # Buat workbook baru
        Create Workbook    emas.xlsx
        
        # Buat worksheet dengan semua data (data baru di atas)
        Create Worksheet    name=Harga_Barang    content=${all_data}    header=True
        
        # HAPUS SHEET DEFAULT setelah membuat worksheet Harga_Barang
        ${sheets}=    List Worksheets
        Log    Worksheets sebelum penghapusan: ${sheets}    console=True
        
        FOR    ${sheet}    IN    @{sheets}
            IF    '${sheet}' in ['Sheet', 'Sheet1'] and '${sheet}' != 'Harga_Barang'
                Remove Worksheet    name=${sheet}
                Log    Dihapus sheet default: ${sheet}    console=True
            END
        END
        
        Save Workbook
        
        Log    \n✅ Data berhasil disimpan ke Excel    console=True
        Log    Simbol perubahan: ▲=Naik, ▼=Turun, -=Stabil    console=True
        Log    \nJalankan file Formatting.robot untuk menambahkan warna    console=True
        
    ELSE
        # Buat workbook baru
        Create Workbook    emas.xlsx
        
        # Buat worksheet Harga_Barang
        Create Worksheet    name=Harga_Barang
        
        # Buat data pertama (tidak ada perbandingan, jadi tanda strip)
        &{first_row}=    Create Dictionary
        ...    Tanggal=${today_datetime}
        ...    Harga Beli=${harga_beli_text}
        ...    Perubahan Beli=-
        ...    Harga Jual=${harga_jual_text}
        ...    Perubahan Jual=-
        
        ${data}=    Create List    ${first_row}
        Append Rows To Worksheet    ${data}    name=Harga_Barang    header=True
        
        # HAPUS SHEET DEFAULT setelah membuat worksheet Harga_Barang
        ${sheets}=    List Worksheets
        Log    Worksheets sebelum penghapusan: ${sheets}    console=True
        
        FOR    ${sheet}    IN    @{sheets}
            IF    '${sheet}' in ['Sheet', 'Sheet1'] and '${sheet}' != 'Harga_Barang'
                Remove Worksheet    name=${sheet}
                Log    Dihapus sheet default: ${sheet}    console=True
            END
        END
        
        Save Workbook
        
        Log    \n✅ File Excel baru dibuat    console=True
        Log    \nJalankan file Formatting.robot untuk menambahkan warna    console=True
    END

    # Buat juga laporan HTML dengan warna
    Create HTML Report    ${all_data}
    
    [Teardown]    Close All Browsers

*** Keywords ***
Extract Numeric Value
    [Arguments]    ${text}
    
    # Gunakan Regex dari String library
    ${cleaned}=    Get Regexp Matches    ${text}    ([0-9.,]+)    1
    
    # Cek apakah ada hasil regex
    IF    not ${cleaned}
        RETURN    ${0}    # Return 0 jika tidak ada angka
    END
    
    ${cleaned}=    Set Variable    ${cleaned}[0]
    
    # Hapus titik pemisah ribuan
    ${cleaned}=    Replace String    ${cleaned}    .    ${EMPTY}
    # Ganti koma dengan titik untuk desimal
    ${cleaned}=    Replace String    ${cleaned}    ,    .
    ${cleaned}=    Strip String    ${cleaned}
    
    # Konversi ke float
    ${numeric}=    Convert To Number    ${cleaned}
    
    RETURN    ${numeric}

Determine Arrow
    [Arguments]    ${harga_sekarang}    ${harga_sebelumnya}
    
    # Jika tidak ada data sebelumnya, return strip
    IF    ${harga_sebelumnya} == 0
        RETURN    -
    # Jika harga sama (tidak ada perubahan), return strip
    ELSE IF    ${harga_sekarang} == ${harga_sebelumnya}
        RETURN    -
    # Jika harga naik, return panah atas
    ELSE IF    ${harga_sekarang} > ${harga_sebelumnya}
        RETURN    ▲
    # Jika harga turun, return panah bawah
    ELSE
        RETURN    ▼
    END

Create HTML Report
    [Arguments]    ${data}
    
    ${html}=    Set Variable    <!DOCTYPE html>
    ${html}=    Catenate    ${html}    <html><head>
    ${html}=    Catenate    ${html}    <title>Laporan Harga Emas Pegadaian</title>
    ${html}=    Catenate    ${html}    <style>
    ${html}=    Catenate    ${html}    body { font-family: Arial, sans-serif; margin: 20px; }
    ${html}=    Catenate    ${html}    h2 { color: #333; }
    ${html}=    Catenate    ${html}    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    ${html}=    Catenate    ${html}    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
    ${html}=    Catenate    ${html}    th { background-color: #4CAF50; color: white; }
    ${html}=    Catenate    ${html}    tr:nth-child(even) { background-color: #f2f2f2; }
    ${html}=    Catenate    ${html}    .naik { color: green; font-weight: bold; }
    ${html}=    Catenate    ${html}    .turun { color: red; font-weight: bold; }
    ${html}=    Catenate    ${html}    .stabil { color: black; }
    ${html}=    Catenate    ${html}    .timestamp { font-size: 12px; color: #666; margin-top: 20px; }
    ${html}=    Catenate    ${html}    </style></head><body>
    
    ${html}=    Catenate    ${html}    <h2>📊 Laporan Harga Emas Pegadaian</h2>
    ${html}=    Catenate    ${html}    <table>
    ${html}=    Catenate    ${html}    <tr>
    ${html}=    Catenate    ${html}    <th>Tanggal</th>
    ${html}=    Catenate    ${html}    <th>Harga Beli</th>
    ${html}=    Catenate    ${html}    <th>Perubahan Beli</th>
    ${html}=    Catenate    ${html}    <th>Harga Jual</th>
    ${html}=    Catenate    ${html}    <th>Perubahan Jual</th>
    ${html}=    Catenate    ${html}    </tr>
    
    ${count}=    Set Variable    0
    FOR    ${row}    IN    @{data}
        ${count}=    Evaluate    ${count} + 1
        
        # Tentukan class CSS berdasarkan simbol
        ${class_beli}=    Set Variable    stabil
        IF    '${row}[Perubahan Beli]' == '▲'
            ${class_beli}=    Set Variable    naik
        ELSE IF    '${row}[Perubahan Beli]' == '▼'
            ${class_beli}=    Set Variable    turun
        END
        
        ${class_jual}=    Set Variable    stabil
        IF    '${row}[Perubahan Jual]' == '▲'
            ${class_jual}=    Set Variable    naik
        ELSE IF    '${row}[Perubahan Jual]' == '▼'
            ${class_jual}=    Set Variable    turun
        END
        
        # Baris pertama (terbaru) beri background berbeda
        ${row_style}=    Set Variable
        IF    ${count} == 1
            ${row_style}=    Set Variable    style="background-color: #e8f5e8;"
        ELSE
            ${row_style}=    Set Variable
        END
        
        ${html}=    Catenate    ${html}    <tr ${row_style}>
        ${html}=    Catenate    ${html}    <td>${row}[Tanggal]</td>
        ${html}=    Catenate    ${html}    <td>${row}[Harga Beli]</td>
        ${html}=    Catenate    ${html}    <td class="${class_beli}">${row}[Perubahan Beli]</td>
        ${html}=    Catenate    ${html}    <td>${row}[Harga Jual]</td>
        ${html}=    Catenate    ${html}    <td class="${class_jual}">${row}[Perubahan Jual]</td>
        ${html}=    Catenate    ${html}    </tr>
    END
    
    ${html}=    Catenate    ${html}    </table>
    
    # Tambahkan legend
    ${html}=    Catenate    ${html}    <div style="margin-top: 30px;">
    ${html}=    Catenate    ${html}    <h3>Keterangan:</h3>
    ${html}=    Catenate    ${html}    <ul>
    ${html}=    Catenate    ${html}    <li><span class="naik">▲</span> = Harga Naik</li>
    ${html}=    Catenate    ${html}    <li><span class="turun">▼</span> = Harga Turun</li>
    ${html}=    Catenate    ${html}    <li><span class="stabil">-</span> = Harga Stabil/Tidak ada data sebelumnya</li>
    ${html}=    Catenate    ${html}    </ul>
    ${html}=    Catenate    ${html}    </div>
    
    # Timestamp
    ${current_time}=    Get Time    result_format=%Y-%m-%d %H:%M:%S
    ${html}=    Catenate    ${html}    <div class="timestamp">
    ${html}=    Catenate    ${html}    <p>Laporan dibuat pada: ${current_time}</p>
    ${html}=    Catenate    ${html}    <p>Sumber data: <a href="https://www.pegadaian.co.id" target="_blank">Pegadaian.co.id</a></p>
    ${html}=    Catenate    ${html}    </div>
    
    ${html}=    Catenate    ${html}    </body></html>
    
    # Simpan file HTML
    ${html_path}=    Set Variable    laporan_emas.html
    Create File    ${html_path}    ${html}
    
    Log    \n🌐 Laporan HTML berwarna dibuat: ${html_path}    console=True
    Log    Buka file tersebut di browser untuk melihat dengan warna    console=True