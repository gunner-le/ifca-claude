# CMSD-66 — Title Registration: Add > Save báo "String was not recognized as a valid DateTime"

- **Client:** CMSD (clone từ NAIM — trang `_NAIMCAP`)
- **Module:** Property Sales > Product Management > Title Registration > Add Title
- **Trang:** `PSUnit/PSUnitTitleAddRegistration_NAIMCAP.aspx(.cs)` (mở từ `PSUnit/PSUnitTitleList_NAIMCAP.aspx`, `TabNo=PS.Unittitle_NAIMCAP`)
- **Bản standard tương ứng:** `PSUnit/PSUnitTitleAddRegistration.aspx.cs` — **cùng lỗi**
- **Trạng thái:** Đã fix & test OK trên Train (2026-11-17)

## Triệu chứng

Add Title với Title Type = Land Title, Title No = `CL 015678`, Receive Date = 01/01/2026, **Issue Date và Expiry Date để trống** → bấm Save → yellow page:

```
System.FormatException: String was not recognized as a valid DateTime.
Line 79: if (DateComparison(System.Convert.ToDateTime(_IssueDate.Value), ...
```

## Root cause

Hàm `DataSave` validate thứ tự ngày (Issue ≤ Receive ≤ Expiry) trước khi lưu:

- Chỉ kiểm tra `_ReceiveDate` / `_ExpiryDate` có rỗng không, **không kiểm tra `_IssueDate`** trước khi `Convert.ToDateTime`.
- `WebDateChooser.Value` khi ô ngày trống trả về chuỗi rỗng `""` (không phải `null` — nếu `null` thì `.ToString()` ở dòng trên đã NullReferenceException). `Convert.ToDateTime("")` ném `FormatException` (`Convert.ToDateTime(null)` thì trả `DateTime.MinValue`, không lỗi).
- 2 điểm dính lỗi:
  1. Issue trống + Receive có giá trị → lỗi (case ticket).
  2. Issue trống + Expiry có giá trị → cùng lỗi (nhánh Expiry).
- Issue Date không bắt buộc (không có `*` trên form) → fix đúng là **bỏ qua phép so sánh khi 1 vế trống**, không bắt nhập.
- Đoạn validate có từ 2010 (comment "Modify by liguang lu 2010/04/20"), **giống hệt ở bản standard** → bug sản phẩm gốc, không phải do customize NAIM/CMSD. Bản `_NAIMCAP` chỉ khác standard ở đoạn insert/update `PropertyCost` vào `PS_UnitTitleItem_NAIMCAP` (không liên quan lỗi).

## Fix (áp dụng cho cả `_NAIMCAP` và standard)

Thay nguyên khối validate từ `//Modify by liguang lu 2010/04/20` (lần đầu) tới hết khối `if (_ExpiryDate != null) { ... }`:

Before:
```csharp
        //Modify by liguang lu 2010/04/20
        if (!string.IsNullOrEmpty(_ReceiveDate.Value.ToString()))
        {
            if (DateComparison(System.Convert.ToDateTime(_IssueDate.Value), System.Convert.ToDateTime(_ReceiveDate.Value)))
            {
                msgTitle.Msg = Strings.GetString("Receive_Err");
                Page.ClientScript.RegisterStartupScript(GetType(), "Result", msgTitle.GetHtml());
                return;
            }
        }
        if (_ExpiryDate != null)
        {
            if (_ExpiryDate.Value.ToString() != "")
            {
                if (DateComparison(System.Convert.ToDateTime(_IssueDate.Value), System.Convert.ToDateTime(_ExpiryDate.Value)))
                {
                    msgTitle.Msg = Strings.GetString("ExpiryDate_Err");
                    Page.ClientScript.RegisterStartupScript(GetType(), "Result", msgTitle.GetHtml());
                    return;
                }
                //Modify by liguang lu 2010/04/20
                if (!string.IsNullOrEmpty(_ReceiveDate.Value.ToString()))
                {
                    if (DateComparison(System.Convert.ToDateTime(_ReceiveDate.Value), System.Convert.ToDateTime(_ExpiryDate.Value)))
                    {
                        msgTitle.Msg = Strings.GetString("ExpiryDate_Err");
                        Page.ClientScript.RegisterStartupScript(GetType(), "Result", msgTitle.GetHtml());
                        return;
                    }
                }
            }
        }
```

After:
```csharp
        // CMSD-66: only compare dates when both sides have a value (Issue/Receive/Expiry Date are optional)
        string strIssue   = (_IssueDate   != null) ? System.Convert.ToString(_IssueDate.Value).Trim()   : "";
        string strReceive = (_ReceiveDate != null) ? System.Convert.ToString(_ReceiveDate.Value).Trim() : "";
        string strExpiry  = (_ExpiryDate  != null) ? System.Convert.ToString(_ExpiryDate.Value).Trim()  : "";

        if (strIssue != "" && strReceive != "")
        {
            if (DateComparison(System.Convert.ToDateTime(_IssueDate.Value), System.Convert.ToDateTime(_ReceiveDate.Value)))
            {
                msgTitle.Msg = Strings.GetString("Receive_Err");
                Page.ClientScript.RegisterStartupScript(GetType(), "Result", msgTitle.GetHtml());
                return;
            }
        }
        if (strExpiry != "")
        {
            if (strIssue != "")
            {
                if (DateComparison(System.Convert.ToDateTime(_IssueDate.Value), System.Convert.ToDateTime(_ExpiryDate.Value)))
                {
                    msgTitle.Msg = Strings.GetString("ExpiryDate_Err");
                    Page.ClientScript.RegisterStartupScript(GetType(), "Result", msgTitle.GetHtml());
                    return;
                }
            }
            if (strReceive != "")
            {
                if (DateComparison(System.Convert.ToDateTime(_ReceiveDate.Value), System.Convert.ToDateTime(_ExpiryDate.Value)))
                {
                    msgTitle.Msg = Strings.GetString("ExpiryDate_Err");
                    Page.ClientScript.RegisterStartupScript(GetType(), "Result", msgTitle.GetHtml());
                    return;
                }
            }
        }
```

Logic so sánh (`DateComparison`, message `Receive_Err`/`ExpiryDate_Err`) giữ nguyên. `Convert.ToString(null)` = `""` nên an toàn cả khi `Value` null.

## Test (Train)

| Issue | Receive | Expiry | Mong đợi |
|---|---|---|---|
| trống | 01/01/2026 | trống | Lưu OK (case ticket) |
| trống | trống | có | Lưu OK |
| trống | có | có, < Receive | Báo `ExpiryDate_Err` |
| có | có, < Issue | trống | Báo `Receive_Err` |
| đủ 3, hợp lệ | | | Lưu OK, `PropertyCost` ghi vào `PS_UnitTitleItem_NAIMCAP` |

Kết quả: Gunner test OK (2026-11-17).

## Còn lại

- Deploy bản `_NAIMCAP` lên Live CMSD.
- Commit fix bản standard `PSUnitTitleAddRegistration.aspx.cs` lên TFS (Train + Live) — NAIM và các client dùng Title Registration chuẩn cũng bị.

## Gotcha dùng chung

- `WebDateChooser.Value` (Infragistics) khi ô ngày trống = `""` → `Convert.ToDateTime(Value)` ném `FormatException "String was not recognized as a valid DateTime"`. Mọi chỗ convert ngày từ `WebDateChooser` không bắt buộc phải check rỗng trước (dùng `Convert.ToString(x.Value).Trim() != ""`).

## Root Cause / Fix note (English, for Jira)

**Root Cause:**
In `DataSave` of the Add Title screen (`PSUnitTitleAddRegistration_NAIMCAP.aspx.cs`), the date-sequence validation converts Issue Date with `Convert.ToDateTime()` whenever Receive Date or Expiry Date is filled, without checking whether Issue Date itself is blank. A blank date picker returns an empty string, so the conversion throws "String was not recognized as a valid DateTime". The same code exists in the standard page `PSUnitTitleAddRegistration.aspx.cs`, so this is a standard product bug, not specific to CMSD customization.

**Fix:**
Date comparisons (Issue vs Receive, Issue vs Expiry, Receive vs Expiry) are now only performed when both dates in the pair have a value. Issue/Receive/Expiry Date remain optional; the existing validation messages are unchanged.

**Status:**
Fixed and tested on Train (blank Issue Date with Receive/Expiry Date filled now saves successfully; invalid date sequences are still blocked). Pending deployment to Live; standard page fix to be committed to TFS.
