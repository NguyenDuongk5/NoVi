$ErrorActionPreference = 'Stop'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$source = 'C:\Users\thain\Desktop\AppDocTruyen\Anh'
$backend = 'C:\Users\thain\Desktop\AppDocTruyen\NVTDuong_AppReadBook_BE-\ReadBook\ReadBookApi'
$destination = Join-Path $backend 'wwwroot\uploads\test\demo-covers'

$target = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute='SELECT DATABASE()'
if ($target -ne 'novi_test') { throw "Từ chối database đích: $target" }

$items = @(
  @{ Id='91000000-0000-0000-0000-000000000001'; Source='Bên nhau trọn đời.jpg'; File='ben-nhau-tron-doi.jpg'; Title='Bên Nhau Trọn Đời'; Slug='novi-demo-ben-nhau-tron-doi'; Category='Ngôn tình' },
  @{ Id='91000000-0000-0000-0000-000000000002'; Source='Chiếc bật lửa và váy công chúa.jpg'; File='chiec-bat-lua-va-vay-cong-chua.jpg'; Title='Chiếc Bật Lửa Và Váy Công Chúa'; Slug='novi-demo-chiec-bat-lua-va-vay-cong-chua'; Category='Ngôn tình' },
  @{ Id='91000000-0000-0000-0000-000000000003'; Source='Khó dỗ dành.jpg'; File='kho-do-danh.jpg'; Title='Khó Dỗ Dành'; Slug='novi-demo-kho-do-danh'; Category='Ngôn tình' },
  @{ Id='91000000-0000-0000-0000-000000000004'; Source='Miển thư.jpg'; File='mien-thu.jpg'; Title='Miển Thư'; Slug='novi-demo-mien-thu'; Category='Chưa phân loại' },
  @{ Id='91000000-0000-0000-0000-000000000005'; Source='Một lít nước mắt.jpg'; File='mot-lit-nuoc-mat.jpg'; Title='Một Lít Nước Mắt'; Slug='novi-demo-mot-lit-nuoc-mat'; Category='Hồi ký' },
  @{ Id='91000000-0000-0000-0000-000000000006'; Source='Nhật thực toàn phần.jpg'; File='nhat-thuc-toan-phan.jpg'; Title='Nhật Thực Toàn Phần'; Slug='novi-demo-nhat-thuc-toan-phan'; Category='Chưa phân loại' },
  @{ Id='91000000-0000-0000-0000-000000000007'; Source='Nếu biết trăm năm là hữu hạn.jpg'; File='neu-biet-tram-nam-la-huu-han.jpg'; Title='Nếu Biết Trăm Năm Là Hữu Hạn'; Slug='novi-demo-neu-biet-tram-nam-la-huu-han'; Category='Tản văn' },
  @{ Id='91000000-0000-0000-0000-000000000008'; Source='Trên đồi, mở mắt và mơ.jpg'; File='tren-doi-mo-mat-va-mo.jpg'; Title='Trên Đồi, Mở Mắt Và Mơ'; Slug='novi-demo-tren-doi-mo-mat-va-mo'; Category='Thiếu nhi' },
  @{ Id='91000000-0000-0000-0000-000000000009'; Source='Trốn lên mái nhà để khóc.jpg'; File='tron-len-mai-nha-de-khoc.jpg'; Title='Trốn Lên Mái Nhà Để Khóc'; Slug='novi-demo-tron-len-mai-nha-de-khoc'; Category='Chưa phân loại' },
  @{ Id='91000000-0000-0000-0000-000000000010'; Source='Tìm đến chốn bình yên.jpg'; File='tim-den-chon-binh-yen.jpg'; Title='Tìm Đến Chốn Bình Yên'; Slug='novi-demo-tim-den-chon-binh-yen'; Category='Chưa phân loại' },
  @{ Id='91000000-0000-0000-0000-000000000011'; Source='Tăng hạ.jpg'; File='tang-ha.jpg'; Title='Tăng Hạ'; Slug='novi-demo-tang-ha'; Category='Chưa phân loại' },
  @{ Id='91000000-0000-0000-0000-000000000012'; Source='Xuân khởi.jpg'; File='xuan-khoi.jpg'; Title='Xuân Khởi'; Slug='novi-demo-xuan-khoi'; Category='Ngôn tình' },
  @{ Id='91000000-0000-0000-0000-000000000013'; Source='Đám trẻ ở đại dương đen.jpg'; File='dam-tre-o-dai-duong-den.jpg'; Title='Đám Trẻ Ở Đại Dương Đen'; Slug='novi-demo-dam-tre-o-dai-duong-den'; Category='Chưa phân loại' },
  @{ Id='91000000-0000-0000-0000-000000000014'; Source='Đốt cháy.jpg'; File='dot-chay.jpg'; Title='Đốt Cháy'; Slug='novi-demo-dot-chay'; Category='Ngôn tình' }
)

$notice = 'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.'
$descriptions = @{
  '91000000-0000-0000-0000-000000000001' = "$notice Bản ghi dùng bìa Bên Nhau Trọn Đời để kiểm thử trình đọc; dự án chưa bổ sung tác giả hoặc tóm tắt cốt truyện đã xác minh."
  '91000000-0000-0000-0000-000000000002' = "$notice Bản ghi dùng bìa Chiếc Bật Lửa Và Váy Công Chúa cho dữ liệu demo; không đại diện nội dung xuất bản và chưa xác nhận thông tin tác giả."
  '91000000-0000-0000-0000-000000000003' = "$notice Bản ghi Khó Dỗ Dành chỉ phục vụ thử giao diện, tìm kiếm và chuyển chương; chưa cung cấp phần giới thiệu chính thức."
  '91000000-0000-0000-0000-000000000004' = "$notice Bản ghi Miển Thư giữ đúng tên đọc trên bìa; thể loại, tác giả và cốt truyện vẫn cần nguồn thông tin bổ sung."
  '91000000-0000-0000-0000-000000000005' = "$notice Bản ghi Một Lít Nước Mắt dùng để kiểm tra hiển thị bìa và chương demo; phần văn bản bên dưới hoàn toàn do dự án tự viết."
  '91000000-0000-0000-0000-000000000006' = "$notice Bản ghi Nhật Thực Toàn Phần chưa có metadata cốt truyện đã xác minh; các chương chỉ mô phỏng trải nghiệm đọc."
  '91000000-0000-0000-0000-000000000007' = "$notice Bản ghi Nếu Biết Trăm Năm Là Hữu Hạn phục vụ kiểm thử ứng dụng; không trích dẫn hoặc tóm lược văn bản của sách."
  '91000000-0000-0000-0000-000000000008' = "$notice Bản ghi Trên Đồi, Mở Mắt Và Mơ dùng bìa đã cung cấp; các cảnh trong chương demo không phải tình tiết của tác phẩm."
  '91000000-0000-0000-0000-000000000009' = "$notice Bản ghi Trốn Lên Mái Nhà Để Khóc chỉ dùng cho môi trường thử nghiệm; dự án chưa xác nhận tác giả và nội dung chính thức."
  '91000000-0000-0000-0000-000000000010' = "$notice Bản ghi Tìm Đến Chốn Bình Yên dùng để thử tủ sách và lịch sử đọc; không khẳng định bất kỳ cốt truyện gốc nào."
  '91000000-0000-0000-0000-000000000011' = "$notice Bản ghi Tăng Hạ giữ trạng thái Chưa phân loại vì bìa chưa đủ căn cứ; chương demo không mô tả tác phẩm thật."
  '91000000-0000-0000-0000-000000000012' = "$notice Bản ghi Xuân Khởi phục vụ thử bố cục và tiến độ đọc; thông tin tác giả và giới thiệu chính thức chưa được cung cấp."
  '91000000-0000-0000-0000-000000000013' = "$notice Bản ghi Đám Trẻ Ở Đại Dương Đen dùng cho trình đọc demo; văn bản không sao chép hay diễn giải nội dung sách."
  '91000000-0000-0000-0000-000000000014' = "$notice Bản ghi Đốt Cháy phục vụ kiểm thử NoVi; các chương minh họa là văn bản độc lập do dự án tạo."
}

$chapterSets = @{
  '91000000-0000-0000-0000-000000000001' = @(
    @('Khoảng cách trên trang giấy','Một giao lộ được vẽ bằng vài nét chì, hai dấu chấm đứng ở hai phía và khoảng trống ở giữa dành cho người đọc tưởng tượng. Khi cuộn xuống, những mảng màu đổi chậm từ vàng sang xanh, đủ dài để thử lưu vị trí mà không kể câu chuyện của tác phẩm.'),
    @('Dấu trang cuối buổi','Buổi đọc thử khép lại bằng một chiếc lá giấy đặt cạnh lề. Người đọc có thể đổi cỡ chữ, quay lại đoạn trước rồi đóng màn hình; dấu trang điện tử cần đưa họ trở về đúng nơi này.')
  )
  '91000000-0000-0000-0000-000000000002' = @(
    @('Hai vật thể trong khung hình','Trang minh họa đặt một nguồn sáng nhỏ cạnh dải màu hồng, dùng tương phản để kiểm tra nền sáng và nền tối. Không nhân vật hay tình tiết nào của sách được tái hiện trong đoạn thử này.'),
    @('Ánh sáng chuyển màu','Các câu ngắn dần nhường chỗ cho một đoạn dài hơn, giúp kiểm tra xuống dòng trên màn hình hẹp. Ở cuối trang, ánh sáng chỉ còn là một chấm màu và nút chuyển chương trở thành điểm tương tác tiếp theo.')
  )
  '91000000-0000-0000-0000-000000000003' = @(
    @('Trạm chờ buổi sớm','Một trạm chờ tưởng tượng hiện ra trong bản demo, với ghế gỗ, bóng cây và bảng giờ không ghi địa danh. Cảnh trung tính này chỉ giúp người dùng thử cuộn, chọn nền đọc và đánh dấu tiến độ.'),
    @('Lời nhắn chưa gửi','Trên trang giấy thử có một ô tin nhắn để trống. Thay vì viết hộ nhân vật, bản demo mời người đọc kiểm tra bàn phím, nút quay lại và khả năng tiếp tục từ phần trăm đã lưu.')
  )
  '91000000-0000-0000-0000-000000000004' = @(
    @('Quỹ đạo màu xanh','Những vòng tròn nhiều màu trôi qua nền xanh như các điểm mốc của một bài kiểm tra thị giác. Mỗi mốc mang một con số, giúp xác định vị trí cuộn mà không gán ý nghĩa cốt truyện cho bìa.'),
    @('Ngôi sao đánh dấu','Một ngôi sao giấy nằm ở giữa trang, bên dưới là ba khoảng văn có độ dài khác nhau. Bố cục được tạo để thử font lớn, khoảng cách dòng và việc khôi phục vị trí sau khi mở lại ứng dụng.')
  )
  '91000000-0000-0000-0000-000000000005' = @(
    @('Trang thử màu lam','Màn hình chuyển sang một sắc lam dịu và hiển thị các câu hoàn toàn mới về việc chăm sóc trải nghiệm đọc. Không chi tiết tiểu sử hay sự kiện nào của tác phẩm được đưa vào dữ liệu này.'),
    @('Một khoảng nghỉ','Giữa hai đoạn văn là khoảng trắng rộng để người dùng nhận biết tiến độ cuộn. Khi rời chương, ứng dụng cần lưu điểm dừng nhưng không biến thao tác lưu phần trăm thành một lượt đọc mới.')
  )
  '91000000-0000-0000-0000-000000000006' = @(
    @('Vòng sáng thử nghiệm','Một vòng sáng tưởng tượng đi qua ba mức độ đậm nhạt, tạo nhịp cho trang đọc demo. Đây chỉ là chỉ dẫn thị giác dùng để thử theme, không phải mô tả sự kiện hay nhân vật của tác phẩm.'),
    @('Khi màn hình dịu lại','Phần cuối giảm số câu và tăng khoảng cách, giúp quan sát thanh công cụ tự ẩn rồi xuất hiện. Người đọc có thể chuyển nền mà không làm thay đổi chương hoặc gửi sai tiến độ.')
  )
  '91000000-0000-0000-0000-000000000007' = @(
    @('Một trăm ô trống','Bản demo xếp những ô vuông nhỏ thành một hàng tượng trưng cho các mốc đọc, nhưng không gán chúng với nội dung sách. Mục tiêu là kiểm tra văn bản dài hiển thị ổn định và dễ theo dõi.'),
    @('Giới hạn của trang thử','Trang này có điểm bắt đầu, điểm dừng và một nút chuyển chương rõ ràng. Những giới hạn ấy giúp kiểm tra lịch sử đọc, trong khi phần ý nghĩa của tác phẩm vẫn được để nguyên, không suy diễn.')
  )
  '91000000-0000-0000-0000-000000000008' = @(
    @('Ngọn đồi bằng giấy','Một ngọn đồi được gấp từ giấy màu, trên đó có các ký hiệu dùng để kiểm tra độ tương phản. Cảnh do dự án tạo không đại diện cho bối cảnh hoặc nhân vật trong tác phẩm.'),
    @('Mở trang kế tiếp','Năm hình tròn xuất hiện theo thứ tự từ nhỏ đến lớn để người đọc thử cuộn chậm. Khi hình cuối rời khỏi màn hình, tiến độ có thể được lưu và khôi phục ở lần mở sau.')
  )
  '91000000-0000-0000-0000-000000000009' = @(
    @('Mái nhà mô hình','Một mô hình mái nhà bằng bìa cứng được đặt trên bàn thử giao diện. Ánh đèn, chiếc thang giấy và khoảng trời đều là chi tiết mới do dự án tạo, không phải nội dung sách.'),
    @('Âm thanh ngoài khung','Trang demo không phát âm thanh; nó chỉ dùng những dòng dài ngắn xen kẽ để mô phỏng nhịp đọc. Người dùng có thể thoát ở bất kỳ đoạn nào và kiểm tra thanh Đọc tiếp trên Trang chủ.')
  )
  '91000000-0000-0000-0000-000000000010' = @(
    @('Bản đồ không địa danh','Một bản đồ thử chỉ có đường nét và mảng màu, không ghi thành phố hay hành trình cụ thể. Nó cung cấp điểm tựa thị giác cho bài kiểm tra cuộn mà không đặt ra cốt truyện.'),
    @('Điểm dừng màu cam','Dấu tròn màu cam đánh dấu gần cuối văn bản, nơi ứng dụng nên ghi nhận phần trăm hiện tại. Nếu mở lại, trình đọc cần trở về dấu này sau khi nội dung đã hoàn tất bố cục.')
  )
  '91000000-0000-0000-0000-000000000011' = @(
    @('Hai gam màu','Trang thử chia thành hai vùng màu với độ sáng khác nhau để kiểm tra chữ và icon. Vì metadata chưa đầy đủ, đoạn văn không suy luận thể loại, thời đại hoặc mối quan hệ nhân vật.'),
    @('Đường kẻ giữa trang','Một đường kẻ mảnh phân cách các đoạn, giúp nhận biết khi cỡ chữ thay đổi làm nội dung dồn xuống. Điểm đọc mới chỉ được gửi sau thao tác của người dùng, không phải do theme thay đổi.')
  )
  '91000000-0000-0000-0000-000000000012' = @(
    @('Mảng trời đầu trang','Trang demo bắt đầu bằng mảng màu sáng và các câu mô tả chính thao tác đọc. Không mùa, địa điểm hay nhân vật nào được khẳng định là thuộc tác phẩm gốc.'),
    @('Bước qua khung chữ','Mỗi đoạn có độ dài riêng để thử chuyển từ chữ thường sang chữ lớn. Nút chương trước và chương sau vẫn giữ vị trí dễ chạm, còn tiến độ được gắn đúng chương đang mở.')
  )
  '91000000-0000-0000-0000-000000000013' = @(
    @('Lớp màu dưới sâu','Những lớp xanh xếp chồng tạo thành nền tưởng tượng cho bài kiểm tra tương phản. Văn bản chỉ nói về giao diện và không tái hiện trải nghiệm, lời kể hoặc nội dung của sách.'),
    @('Điểm sáng trên màn hình','Các điểm sáng nhỏ được nhắc tới như mốc kỹ thuật để người đọc dừng lại. Khi quay về lịch sử, ứng dụng phải hiển thị đúng tên truyện và chương mà không lộ nội dung nếu chương bị ẩn.')
  )
  '91000000-0000-0000-0000-000000000014' = @(
    @('Dải màu ấm','Một dải màu ấm lan từ trái sang phải trên trang minh họa, phục vụ kiểm tra nền và độ sáng chữ. Không sự kiện nào của tác phẩm thật được mô tả trong phần này.'),
    @('Khép lại bản thử','Dòng cuối đánh dấu kết thúc bộ văn bản tự sáng tác cho trình đọc. Người dùng có thể quay lại chương đầu, và hệ thống vẫn phải phân biệt hành động đọc lại với request tiến độ đến muộn.')
  )
}

New-Item -ItemType Directory -Force -Path $destination | Out-Null
foreach ($item in $items) {
  Copy-Item -LiteralPath (Join-Path $source $item.Source) -Destination (Join-Path $destination $item.File) -Force
}

$ownerId = '90000000-0000-0000-0000-000000000001'
$categories = @{
  'Ngôn tình' = @('92000000-0000-0000-0000-000000000001', 'ngon-tinh')
  'Hồi ký' = @('92000000-0000-0000-0000-000000000002', 'hoi-ky')
  'Tản văn' = @('92000000-0000-0000-0000-000000000003', 'tan-van')
  'Thiếu nhi' = @('92000000-0000-0000-0000-000000000004', 'thieu-nhi')
  'Chưa phân loại' = @('92000000-0000-0000-0000-000000000005', 'chua-phan-loai')
}

$sql = "INSERT INTO user(user_id,full_name,email,password_hash,role,status,lock_reason) VALUES('$ownerId','NoVi Demo','novi-demo@novi.test','DEMO_ACCOUNT_DISABLED',1,0,'Tài khoản dữ liệu minh họa') ON DUPLICATE KEY UPDATE full_name=VALUES(full_name);"
foreach ($entry in $categories.GetEnumerator()) {
  $sql += " INSERT INTO category(category_id,name,slug,is_active) VALUES('$($entry.Value[0])','$($entry.Key)','$($entry.Value[1])',1) ON DUPLICATE KEY UPDATE is_active=1;"
}
foreach ($item in $items) {
  $title = $item.Title.Replace("'", "''")
  $description = $descriptions[$item.Id].Replace("'", "''")
  $cover = "/uploads/test/demo-covers/$($item.File)"
  $sql += " INSERT INTO novel(novel_id,title,slug,uploader_id,description,cover_url,review_status,visibility,published_at) VALUES('$($item.Id)','$title','$($item.Slug)','$ownerId','$description','$cover',1,0,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE title=VALUES(title),cover_url=VALUES(cover_url),description=VALUES(description),review_status=1,visibility=0,deleted_at=NULL; DELETE FROM novel_category WHERE novel_id='$($item.Id)'; INSERT INTO novel_category(novel_id,category_id) VALUES('$($item.Id)','$($categories[$item.Category][0])');"
}

$chapterOrdinal = 1
foreach ($item in $items) {
  $number = 1
  foreach ($chapter in $chapterSets[$item.Id]) {
    $chapterId = '93000000-0000-0000-0000-{0:D12}' -f $chapterOrdinal
    $chapterTitle = $chapter[0].Replace("'", "''")
    $chapterContent = ("$notice`n`n$($chapter[1])").Replace("'", "''")
    $sql += " INSERT INTO chapter(chapter_id,novel_id,chapter_number,title,content,review_status,visibility,published_at) VALUES('$chapterId','$($item.Id)',$number,'$chapterTitle','$chapterContent',1,0,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE novel_id=VALUES(novel_id),chapter_number=VALUES(chapter_number),title=VALUES(title),content=VALUES(content),review_status=1,visibility=0,deleted_at=NULL;"
    $number++
    $chapterOrdinal++
  }
}

& $mysql --login-path=novi_test_setup --database=novi_test --default-character-set=utf8mb4 --execute=$sql
if ($LASTEXITCODE -ne 0) { throw 'Seed dữ liệu minh họa thất bại.' }
Write-Host "Đã seed $($items.Count) truyện và $($chapterOrdinal - 1) chương minh họa vào novi_test."
